defmodule Weaver.BuilderV2.Cards do
  alias Weaver.BuilderV2.Weft

  defmacro snapshot do
    quote do
      @cards
    end
  end

  defmacro restore(value) do
    quote do
      @cards unquote(value)
    end
  end

  defmacro push(card) do
    quote do
      @cards @cards ++ [unquote(card)]
    end
  end

  defmacro pop do
    quote do
      try do
        @cards
      after
        @cards []
      end
    end
  end

  defmodule ProviderSpecs do
    @type spec :: %{type: :one | :many, weft: Weaver.BuilderV2.Weft.t, collector: atom, weaver: atom}
    @type provider_identifier :: {atom, integer}
    @type t :: {:digraph.graph, %{provider_identifier => [spec]}}

    def add(specs, provider, dependences, spec) when is_list(dependences) do
      {graph, map} = specs
      identifier = add_dependencies_and_ensure_identifier(specs, {provider, 0}, dependences)
      {_, map} = Map.get_and_update(map, identifier, fn prev ->
        {prev, case prev do
          nil -> [spec]
          specs -> [spec|specs]
        end}
      end)
      {{graph, map}, identifier}
    end

    defp add_dependencies_and_ensure_identifier({graph, _map} = specs, {provider, index} = identifier, dependences) do
      unless :digraph.vertex(graph, identifier) do
        :digraph.add_vertex(graph, identifier)
      end
      case Enum.reduce_while(dependences, [], fn dependence, edges ->
        case :digraph.add_edge(graph, dependence, identifier) do
          {:error, {:bad_edge, _}} ->
            # revert the added edges
            :digraph.del_edges(graph, edges)
            {:halt, :bad_edge}
          edge -> {:cont, [edge|edges]}
        end
      end) do
        :bad_edge -> add_dependencies_and_ensure_identifier(specs, {provider, index + 1}, dependences)
        _ -> identifier
      end
    end

    def new do
      {:digraph.new([:acyclic, :private]), %{}}
    end

    def delete({graph, _}) do
      :digraph.delete(graph)
    end

    def schedule({graph, map}) do
      vertices = :digraph_utils.topsort(graph)
      Enum.reduce(vertices, [], fn {provider, _} = identifier, acc->
        specs = Map.get(map, identifier, [])
        [{provider, specs}|acc]
      end) |> Enum.reverse
    end
  end

  @spec quote_cards_call([Weaver.BuilderV2.Card], Macro.t) :: Macro.t
  def quote_cards_call(cards, item) do
    plans = convert_cards_to_plans(cards)
    call = Enum.reduce(plans, item, &quote_plan_reducer(&1, &2))
    quote do
      unquote(call)
    end
  end

  defp quote_plan_reducer(plan, acc) do
    call = quote_plan_call(plan)
    quote do
      unquote(call).(unquote(acc))
    end
  end

  defp quote_plan_call({provider, specs}) do
    item = quote do: item
    call = Enum.reduce(specs, quote(do: {MapSet.new, nil}), &quote_spec_call_reducer(&1, &2, item))
    quote do
      fn unquote(item) ->
        {ids, tree} = unquote(call)
        entities = unquote(provider).find(MapSet.to_list(ids))
        Weaver.BuilderV2.ObjectTree.map(tree, item, entities, fn item, payload, entities, next ->
          case payload do
            nil -> next.(item, entities)
            map ->
              items = case Map.get(map, :ids, []) do
                x when is_list(x) -> Weaver.Utils.Lists.map_with(x, entities)
                x -> Map.get(entities, x)
              end
              case Map.get(map, :weaver) do
                nil -> next.(items, entities)
                weaver -> next.(weaver.weave(items), entities)
              end
          end
        end)
      end
    end
  end

  defp quote_spec_call_reducer(spec, acc, item) do
    collect_fn = Weft.quote_collect_function(spec.weft, spec.type, spec)
    quote do
      {ids, tree} = unquote(acc)
      case unquote(collect_fn).(unquote(item), tree) do
        nil -> {ids, tree}
        {new_ids, tree} -> {MapSet.union(ids, new_ids), tree}
      end
    end
  end

  defp convert_cards_to_plans(cards) do
    specs = ProviderSpecs.new
    accumulator = {%{
      weft: [],
      dependence: nil,
      prev: nil
    }, specs}
    try do
      {_, specs} = Enum.reduce(cards, accumulator, &card_reducer(&1, &2))
      ProviderSpecs.schedule(specs)
    after
      ProviderSpecs.delete(specs)
    end
  end

  defp card_reducer(card, {context = %{weft: weft, dependence: dependence, prev: prev}, specs}) do
    current_weft = Weft.append(weft, case card.type do
      :one -> {:struct, card.target}
      :many -> {:list, card.target}
    end)
    {specs, dependence} =
      if (card.provider) do
        dependences = [dependence, prev] |> Enum.reject(& &1 == nil)
        ProviderSpecs.add(specs, card.provider, dependences, %{type: card.type, weft: current_weft, collector: card.collector, weaver: card.weaver})
      else
        {specs, dependence}
      end
    unless Enum.empty?(card.children) do
      context = %{weft: current_weft, dependence: dependence, prev: nil}
      {context, specs} = Enum.reduce(card.children, {context, specs}, &card_reducer(&1, &2))
      {%{context| prev: dependence}, specs}
    else
      {%{context| prev: dependence}, specs}
    end
  end

end
