defmodule Weaver.BuilderV2.RelativeCollectorTest do
  use ExUnit.Case, async: true

  alias Weaver.BuilderV2.RelativeCollector

  describe "collect/2" do
    test "should collect item" do
      item = %{m: %{l: [1], v: 1}, l: [1, 2, 3]}
      assert RelativeCollector.collect({item, [], item}, [:m, :v]) == 1
      assert RelativeCollector.collect({item, [], item}, [:m, :l]) == [1]
      assert RelativeCollector.collect({item, [], item}, [:l]) == [1, 2, 3]
      assert RelativeCollector.collect({item, [], item}, [:not_exist]) == nil
    end
  end

  describe "collect_many/2" do
    test "should collect list" do
      item = %{m: %{l: [1], v: 1}, l: [1, 2, 3]}
      assert RelativeCollector.collect_many({item, [], item}, [:m, :v]) == 1
      assert RelativeCollector.collect_many({item, [], item}, [:m, :l]) == [1]
      assert RelativeCollector.collect_many({item, [], item}, [:l]) == [1, 2, 3]
      assert RelativeCollector.collect_many({item, [], item}, [:not_exist]) == []
    end
  end
end
