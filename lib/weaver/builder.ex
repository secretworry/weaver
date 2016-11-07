defmodule Weaver.Builder do
  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :weaver, accumulate: true)
      import Weaver.Builder
      @before_compile Weaver.Builder
      def weave(items) do
        weaver_weave_call(items)
      end
    end
  end

  defmacro __before_compile__(env) do
    weavers = Module.get_attribute(env.module, :weaver)
    if weavers == [] do
      raise "no weaver has been defined in #{inspect env.module}"
    end
    # Validate id_converter
    Enum.each(weavers, fn weaver ->
      if is_map(weaver) and weaver.id_converter != nil do
        unless Module.defines?(env.module, {weaver.id_converter, 1}) do
          raise "id_converter: #{inspect weaver.id_converter} dees not defined in #{env.module}"
        end
      end
    end)
    {items, call} = compile(env, Module.get_attribute(env.module, :weaver))
    quote do
      defp weaver_weave_call(unquote(items)), do: unquote(call)
    end
  end

  defmacro weaver({:%{}, _, tablets}, opts) when is_list(opts) do
    tablets = Enum.reduce(tablets, [], &normalize_tablets_reducer(&1, &2))
    Enum.each(tablets, &validate_tablets(&1))
    weaver = quote do: %Weaver.Builder.Shed{tablets: unquote(tablets)}
    weaver = Enum.reduce(opts, weaver, &build_weaver_reducer(&1, &2))
    quote do
      @weaver unquote(weaver)
    end
  end

  defmacro weaver(weaver) do
    quote do
      @weaver unquote(weaver)
    end
  end

  def normalize_tablets_reducer({collect, assign}, acc) when is_atom(collect) and is_atom(assign) do
    [{[collect], [assign]} | acc]
  end

  def normalize_tablets_reducer({collect, assign}, acc) when is_atom(collect) and is_list(assign) do
    [{[collect], assign} | acc]
  end

  def normalize_tablets_reducer({collect, assign}, acc) when is_list(collect) and is_atom(assign) do
    [{collect, [assign]} | acc]
  end

  def normalize_tablets_reducer(tablet, acc) do
    [tablet | acc]
  end

  def validate_tablets({collect, assign}) do
    validate_weft(collect)
    validate_weft(assign)
  end

  defp is_knot(knot) do
    is_atom(knot) or is_binary(knot)
  end

  def validate_weft([knot]) do
    unless is_list(knot) or is_knot(knot) do
      raise "Last knot of weft accepts only atom|binary or [atom|binary], but got #{inspect knot}"
    end
  end

  def validate_weft([knot|tail]) do
    unless is_knot(knot) do
      raise "Knots of weft accepts only *atom|binary*, but got #{inspect knot}"
    end
    validate_weft(tail)
  end

  def validate_weft([]) do
  end

  defp build_weaver_reducer({:provider, provider}, acc) do
    quote do
      %{unquote(acc) | provider: unquote(provider)}
    end
  end

  defp build_weaver_reducer({:converter, converter}, acc) do
    quote do
      %{unquote(acc) | converter: unquote(converter)}
    end
  end

  defp build_weaver_reducer({:id_converter, converter}, acc) do
    quote do
      %{unquote(acc) | id_converter: unquote(converter)}
    end
  end

  defp build_weaver_reducer({opt, _}, _acc) do
    raise "Unrecognizable opt #{inspect opt}"
  end

  @spec compile(Macro.Env.t, [Weaver.t]) :: {Macro.t, Macro.t}
  def compile(_env, weavers) do
    items = quote do: items
    {items, Enum.reduce(Enum.reverse(weavers), items, &quote_weaver_reducer(&1, &2))}
  end


  defp quote_weaver_reducer(weaver, acc) when is_atom(weaver) do
    quote do
      unquote(weaver).weave(unquote(acc))
    end
  end

  defp quote_weaver_reducer(weaver, acc) do
    item = quote do: item
    assemble_call = quote_assemble(weaver, item)
    quote do
      {ids, item_with_assignments} = Enum.reduce(unquote(acc), {MapSet.new, []}, fn unquote(item), {ids_acc, item_with_assignments} ->
        {ids, assignments} = unquote(assemble_call)
        case ids do
          nil -> {ids_acc, [{unquote(item), []} | item_with_assignments]}
          _ -> {MapSet.union(ids_acc, MapSet.new(ids)), [{unquote(item), assignments} | item_with_assignments]}
        end
      end)
      entities = unquote(weaver.provider).find(MapSet.to_list(ids))
      Enum.reduce(item_with_assignments, [], fn {item, assignments}, acc ->
        item = Enum.reduce(assignments, item, fn {ids, assign}, item ->
          case ids do
            nil -> item
            ids when is_list(ids) ->
              values = Enum.reduce(ids, [], fn id, acc ->
                case Map.get(entities, id) do
                  nil -> acc
                  value -> [value | acc]
                end
              end) |> Enum.reverse
              assign.(item, values)
            _ -> assign.(item, Map.get(entities, ids))
          end
        end)
        [item | acc]
      end)
    end
  end

  defp quote_assemble(weaver, item) do
    init_value = quote do: {[], []}
    Enum.reduce(weaver.tablets, init_value, &quote_assemble_reducer(&1, &2, item, weaver.id_converter))
  end

  defp quote_assemble_reducer({collect, assign}, acc, item, id_converter) do
    return_values = quote do: fn _, values -> values end
    collect_call = Enum.reduce(collect, item, &quote_collect_reducer(&1, &2))
    assign_call = Enum.reduce(Enum.reverse(assign), return_values, &quote_assign_reducer(&1, &2))
    convert_call = case id_converter do
      nil -> quote do: fn id -> id end
      _ -> quote do: fn id -> unquote(id_converter)(id) end
    end
    quote do
      {ids, assigns} = unquote(acc)
      case unquote(collect_call) do
        nil -> {ids, assigns}
        new_ids ->
          new_ids = cond do
            is_list(new_ids) -> Enum.map(new_ids, unquote(convert_call))
            true -> unquote(convert_call).(new_ids)
          end
          ids = cond do
            is_list(new_ids) -> new_ids ++ ids
            true -> [new_ids | ids]
          end
          {ids, [{new_ids, unquote(assign_call)}|assigns]}
      end
    end
  end

  defp quote_collect_reducer([knot], acc) do
    quote do
      case unquote(acc) do
        nil -> nil
        child -> Map.get(item, unquote(knot))
      end
    end
  end

  defp quote_collect_reducer(knot, acc) do
    quote do
      case unquote(acc) do
        nil -> nil
        child -> Map.get(child, unquote(knot))
      end
    end
  end

  defp quote_assign_reducer([knot], acc) do
    quote do
      fn item, values ->
        case item do
          nil -> nil
          _ ->
            child = Map.get(item, unquote(knot))
            new_child = case unquote(acc).(child, values) do
              nil -> []
              new_child -> new_child
            end
            Map.put(item, unquote(knot), new_child)
        end
      end
    end
  end

  defp quote_assign_reducer(knot, acc) do
    quote do
      fn item, values ->
        case item do
          nil -> nil
          _ ->
            child = Map.get(item, unquote(knot))
            new_child = unquote(acc).(child, values)
            Map.put(item, unquote(knot), new_child)
        end
      end
    end
  end
end
