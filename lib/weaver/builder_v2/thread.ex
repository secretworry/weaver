defmodule Weaver.BuilderV2.Thread do
  @type knot :: atom | binary | integer

  @type t :: [knot]

  def valid?(weft) do
    do_valid?(weft)
  end

  def get(_simple_weft, nil) do
    nil
  end

  def get(simple_weft, item) do
    do_get(simple_weft, item)
  end

  defp do_get([knot_id|tail], item) when is_atom(knot_id) or is_binary(knot_id) do
    case Map.get(item, knot_id) do
      nil -> nil
      child -> do_get(tail, child)
    end
  end

  defp do_get([knot_id | tail], item) when is_integer(knot_id) and is_list(item) do
    case Enum.at(item, knot_id) do
      nil -> nil
      child -> do_get(tail, child)
    end
  end

  defp do_get([knot_id | tail], item) when is_integer(knot_id) and is_tuple(item) do
    case elem(item, knot_id) do
      nil -> nil
      child -> do_get(tail, child)
    end
  end

  defp do_get([], item) do
    item
  end

  defp do_valid?([knot_id|tail]) when is_atom(knot_id) or is_binary(knot_id) or is_integer(knot_id) do
    do_valid?(tail)
  end

  defp do_valid?([_knot_id|_tail]) do
    false
  end

  defp do_valid?([]) do
    true
  end

end
