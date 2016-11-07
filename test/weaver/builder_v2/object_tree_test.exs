defmodule Weaver.BuilderV2.ObjectTreeTest do
  use ExUnit.Case, async: true

  alias Weaver.BuilderV2.ObjectTree

  defmodule Item do
    defstruct value: nil
  end

  describe "map/4" do
    test "should map a struct" do
      item = %Item{}
      tree = {nil, %{value: {"test"}}}
      result = ObjectTree.map(tree, item, nil, fn item, payload, context, next ->
        case payload do
          nil -> item
          value -> value
        end
        |> next.(context)
      end)
      assert result == %Item{value: "test"}
    end
    test "should map a list without changing its sequence" do
      tree = {nil, [{0}, {1}, {2}]}
      result = ObjectTree.map(tree, [{0}, {1}, {2}], nil, fn item, payload, context, next ->
        case payload do
          nil -> item
          value -> Tuple.insert_at(item, 1, value)
        end |> next.(context)
      end)
      assert result == [{0, 0}, {1, 1}, {2, 2}]
    end
    test "should handle maps without any problem" do
      item = %{
        :map => %{key: nil},
        :map_map => %{map_key: %{key0: nil, key1: nil}},
        :map_list => [
          %{key: nil},
          %{key: nil}
        ],
        :map_tuple => {%{key: nil}, %{key: nil}}
      }
      tree = {nil, %{
        :map => {nil, %{
          :key => {:map}
        }},
        :map_map => {nil, %{
          :map_key => {nil, %{
            :key0 => {:map0},
            :key1 => {:map1}
          }}
        }},
        :map_list => {nil, [
          {nil, %{
            :key => {:list0}
          }},
          {nil, %{
            :key => {:list1}
          }}
        ]},
        :map_tuple => {nil, {
          {nil, %{
            :key => {:tuple0}
          }},
          {nil, %{
            :key => {:tuple1}
          }}
        }}
      }}
      context = %{
        :map => :map_value,
        :map0 => :map0_value,
        :map1 => :map1_value,
        :list0 => :list_value0,
        :list1 => :list_value1,
        :tuple0 => :tuple_value0,
        :tuple1 => :tuple_value1
      }
      result = ObjectTree.map(tree, item, context, fn item, payload, context, next ->
        case payload do
          nil -> item
          key -> Map.get(context, key)
        end
        |> next.(context)
      end)
      assert result == %{
        :map => %{key: :map_value},
        :map_map => %{map_key: %{
          :key0 => :map0_value,
          :key1 => :map1_value
        }},
        :map_list => [
          %{key: :list_value0},
          %{key: :list_value1}
        ],
        :map_tuple => {%{key: :tuple_value0}, %{key: :tuple_value1}}
      }
    end

    test "should handle lists without any error" do
      item = %{
        :list => [],
        :list_list => [[], []],
        :map_list => %{key0: [], key1: []},
        :tuple_list => {[], []}
      }
      tree = {nil, %{
        :list => {[:id0, :id1]},
        :list_list => {nil, [
          {[:id0, :id1]},
          {[:id1, :id0]}
        ]},
        :map_list => {nil, %{
          key0: {[:id0, :id1]},
          key1: {[:id1, :id0]}
        }},
        :tuple_list => {nil, {
          {[:id0, :id1]},
          {[:id1, :id0]}
        }}
      }}
      context = %{
        :id0 => :id0_value,
        :id1 => :id1_value
      }
      result = ObjectTree.map(tree, item, context, fn item, payload, context, next ->
        case payload do
          nil -> item
          list when is_list(list) -> Enum.map(list, fn key -> Map.get(context, key) end)
        end |> next.(context)
      end)
      assert result == %{
        :list => [:id0_value, :id1_value],
        :list_list => [[:id0_value, :id1_value], [:id1_value, :id0_value]],
        :map_list => %{
          key0: [:id0_value, :id1_value],
          key1: [:id1_value, :id0_value]
        },
        :tuple_list => {[:id0_value, :id1_value], [:id1_value, :id0_value]}
      }
    end
  end
end
