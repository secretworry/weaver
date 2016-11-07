defmodule Weaver.BuilderV2.Weft do
  @type knot_id :: atom | binary

  @type knot :: {:list, knot_id} | {:map, knot_id} | {:tuple, knot_id}

  @type t :: [knot]

  def append(weft, knot) do
    weft ++ [knot]
  end

  def quote_collect_function(weft, type, spec) do
    {last, child_fn_body} = do_quote_to_tree(weft, type, spec)
    context = quote do: context
    tree = quote do: tree
    child_fn = quote do: child_fn
    if last do
      quote do
        fn item, tree ->
          unquote(child_fn_body).({item, [], item}, tree)
        end
      end
    else
      quote do
        unquote(child_fn) = unquote(child_fn_body)
        fn
          nil, tree -> tree
          item, unquote(tree) when is_list(item) ->
            unquote(context) = {item, [], item}
            unquote(do_quote_list_call(context, tree, child_fn))
          item, unquote(tree) when is_tuple(item) ->
            unquote(context) = {item, [], item}
            unquote(do_quote_tuple_call(context, tree, child_fn))
          %{__struct__: _} = item, unquote(tree) when is_map(item) ->
            unquote(child_fn).({item, [], item}, unquote(tree))
          item, unquote(tree) when is_map(item) ->
            unquote(context) = {item, [], item}
            unquote(do_quote_map_call(context, tree, child_fn))
        end
      end
    end
  end

  defp do_quote_list_call(context, tree, child_fn) do
    quote do
      {root, thread, item} = unquote(context)
      {payload, list} = Weaver.BuilderV2.ObjectTree.init_list_node(unquote(tree), item)
      {ids, tree, _} = Enum.zip(list, item) |> Enum.reduce({MapSet.new, [], 0}, fn {tree, ele}, {set, result, index}->
        {ids, tree} = unquote(child_fn).({root, thread ++ [index], ele}, tree)
        {MapSet.union(set, ids), [tree | result], index + 1}
      end)
      {ids, {payload, Enum.reverse(tree)}}
    end
  end

  defp do_quote_tuple_call(context, tree, child_fn) do
    quote do
      {root, thread, item} = unquote(context)
      {payload, tuple} = Weaver.BuilderV2.ObjectTree.init_tuple_node(unquote(tree), item)
      {ids, tree, _} = Enum.zip(tuple |> Tuple.to_list, item |> Tuple.to_list) |> Enum.reduce({MapSet.new, [], 0}, fn {tree, ele}, {set, result, index} ->
        {ids, tree} = unquote(child_fn).({root, thread ++ [index], ele}, tree)
        {MapSet.union(set, ids), [tree | result], index + 1}
      end)
      {ids, {payload, Enum.reverse(tree) |> List.to_tuple}}
    end
  end

  defp do_quote_map_call(context, tree, child_fn) do
    quote do
      {root, thread, item} = unquote(context)
      {payload, map} = Weaver.BuilderV2.ObjectTree.init_map_node(unquote(tree), item)
      {ids, tree} = Enum.reduce(item, {MapSet.new, map}, fn {key, value}, {set, result} ->
        tree = Map.get(result, key)
        {ids, tree} = unquote(child_fn).({root, thread ++ [key], value}, tree)
        {MapSet.union(set, ids), Map.put(result, key, tree)}
      end)
      {ids, {payload, tree}}
    end
  end

  defp do_quote_struct_call(context, tree, child_fn) do
    quote do
      {root, thread, item} = unquote(context)
      {payload, map} = Weaver.BuilderV2.ObjectTree.init_map_node(unquote(tree), item)
      unquote(child_fn).({root, thread, item}, {payload, map})
    end
  end

  defp do_quote_to_tree([{knot_type, knot_id}|tail], type, spec) do
    {last, child_fn_body} = do_quote_to_tree(tail, type, spec)
    context = quote(do: context)
    tree = quote(do: tree)
    child_fn = quote(do: child_fn)
    {item_type, sub_call} = case knot_type do
      :list -> {:list, do_quote_list_call(context, tree, child_fn)}
      :map -> {:map, do_quote_map_call(context, tree, child_fn)}
      :tuple -> {:tuple, do_quote_tuple_call(context, tree, child_fn)}
      :struct -> {:map, do_quote_struct_call(context, tree, child_fn)}
      _ -> raise "Unrecoginizable type #{inspect type}, expects :list, :map or :tuple"
    end
    if last do
      {false, do_quote_last_call(knot_id, child_fn_body)}
    else
      {false, do_quote_non_last_call(item_type, knot_id, context, tree, child_fn, child_fn_body, sub_call)}
    end
  end

  defp do_quote_to_tree([], type, spec) do
    context = quote(do: context)
    call = quote_collect_call(context, type, spec.collector)
    {true, quote do
      fn (unquote(context)) ->
        case unquote(call) do
          nil -> {MapSet.new, {nil}}
          x when is_list(x)-> {MapSet.new(x), {%{ids: x, weaver: unquote(Macro.escape(spec.weaver))}}}
          x -> {MapSet.new([x]), {%{ids: x, weaver: unquote(Macro.escape(spec.weaver))}}}
        end
      end
    end}
  end

  defp do_quote_non_last_call(item_type, knot_id, context, tree, child_fn, child_fn_body, sub_call) do
    quote do
      fn ({root, thread, item}, tree) ->
        unquote(child_fn) = unquote(child_fn_body)
        {payload, map} = Weaver.BuilderV2.ObjectTree.init_map_node(tree, item)
        case Map.get(item, unquote(knot_id)) do
          nil -> {MapSet.new, {payload, map}}
          item when unquote("is_#{item_type}" |> String.to_atom)(item) ->
            unquote(context) = {root, thread ++ [unquote(knot_id)], item}
            unquote(tree) = Map.get(map, unquote(knot_id))
            {ids, child} = unquote(sub_call)
            {ids, {payload, Map.put(map, unquote(knot_id), child)}}
          x -> raise "Expect a #{unquote(item_type)} but get #{inspect x} for item #{inspect item}"
        end
      end
    end
  end

  defp do_quote_last_call(knot_id, child_fn_body) do
    quote do
      fn {_root, _thread, item} = context, tree ->
        {payload, map} = Weaver.BuilderV2.ObjectTree.init_map_node(tree, item)
        {ids, child} = unquote(child_fn_body).(context)
        {ids, {nil, Map.put(map, unquote(knot_id), child)}}
      end
    end
  end

  defp quote_collect_call(context, type, {collector, opts}) do
    opts = Macro.escape(opts)
    case type do
      :one ->
        quote do
          unquote(collector).collect(unquote(context), unquote(opts))
        end
      :many ->
        quote do
          unquote(collector).collect_many(unquote(context), unquote(opts))
        end
      x -> raise "Unrecognizable collector type #{inspect x} should be either :one or :many"
    end
  end
end
