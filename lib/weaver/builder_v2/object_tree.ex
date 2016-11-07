defmodule Weaver.BuilderV2.ObjectTree do

  @type payload :: any

  @type tree_node :: {payload, %{any => tree_node}} | {payload, [tree_node]} | {payload, tuple} | {payload}

  @type t :: tree_node

  def init_list_node(tree, item) when is_list(item) do
    {payload, list} = case tree do
      nil -> {nil, nil}
      x = {_payload, list} when is_list(list) -> x
      {payload} -> {payload, nil}
      _ -> raise "Incompatitable list type for tree #{inspect tree} and item #{inspect item}"
    end
    item_length = length(item)
    {payload, case list do
      nil -> List.duplicate(nil, item_length)
      x when length(x) == item_length -> list
      _ -> raise "Incompatitable length for tree #{inspect list} and item #{inspect item}"
    end}
  end

  def init_list_node(tree, nil) do
    tree
  end

  def init_list_node(_tree, _item) do
    raise "Should init list node with a list"
  end

  def init_map_node(tree, item) when is_map(item) or is_nil(item) do
    case tree do
      nil -> {nil, %{}}
      x = {_payload, map} when is_map(map) -> x
      {payload} -> {payload, %{}}
      _ -> raise "Incompatitable map type for tree #{inspect tree} and item #{inspect item}"
    end
  end

  def init_map_node(_tree, item) do
    raise "Should init map node with a map but get #{inspect item}"
  end

  def init_tuple_node(tree, item) when is_tuple(item) do
    {payload, tuple} = case tree do
      nil -> {nil, nil}
      x = {_payload, tuple} when is_tuple(tuple) -> x
      {payload} -> {payload, nil}
      _ -> raise "Incompatitable tuple type for tree #{inspect tree} and item #{inspect item}"
    end
    size = tuple_size(item)
    {payload, case tuple do
      nil -> (List.duplicate(nil, size) |> List.to_tuple)
      x when tuple_size(x) == size -> x
      _ -> raise "Incompatitable length for tree #{inspect tuple} and item #{inspect item}"
    end}
  end

  def init_tuple_node(tree, nil) do
    tree
  end

  def init_tuple_node(_tree, _item) do
    raise "Should init tuple node with a tuple"
  end

  def map(nil, nil, _, _) do
    nil
  end

  def map({payload, children}, item, context, callback) do
    do_map(item, payload, children, context, callback)
  end

  def map({payload}, item, context, callback) do
    do_map(item, payload, context, callback)
  end

  defp do_map(item, payload, children, context, callback) when is_list(children) do
    do_map_item(item, payload, context, callback, fn callback_item, context ->
      children_length = length(children)
      callback_item = case callback_item do
        nil -> List.duplicate(nil, children_length)
        x when is_list(x) and length(x) == children_length -> x
        _ -> raise "Incompatitable item #{inspect item} and tree #{inspect children}"
      end
      Enum.zip(callback_item, children) |> Enum.map(fn
        {item, {payload, children}}-> do_map(item, payload, children, context, callback)
        {item, {payload}}-> do_map(item, payload, context, callback)
      end)
    end)
  end

  defp do_map(item, payload, children, context, callback) when is_map(children) do
    do_map_item(item, payload, context, callback, fn callback_item, context ->
      Enum.reduce(children, callback_item, fn
        {identifier, {payload, children}}, item -> Map.put(item, identifier, do_map(Map.get(callback_item, identifier), payload, children, context, callback))
        {identifier, {payload}}, item -> Map.put(item, identifier, do_map(Map.get(callback_item, identifier), payload, context, callback))
        x, _-> raise "Illegal tree child: #{inspect x}"
      end)
    end)
  end

  defp do_map(item, payload, children, context, callback) when is_tuple(children) do
    do_map(Tuple.to_list(item), payload, Tuple.to_list(children), context, callback) |> List.to_tuple
  end

  defp do_map(item, payload, context, callback) do
    do_map_item(item, payload, context, callback, fn callback_item, _context ->
      callback_item
    end)
  end

  defp do_map_item(item, payload, context, callback, next) do
    callback.(item, payload, context, fn callback_item, context ->
      next.(callback_item, context)
    end)
  end
end
