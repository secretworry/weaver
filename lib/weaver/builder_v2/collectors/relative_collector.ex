defmodule Weaver.BuilderV2.RelativeCollector do
  @behaviour Weaver.BuilderV2.Collector

  alias Weaver.BuilderV2.Thread

  def collect({_root, _path, item}, opts) do
    Thread.get(opts, item)
  end
  def collect_many({_root, _path, item}, opts) do
    case Thread.get(opts, item) do
      nil -> []
      x when is_list(x) -> x
      x -> x # we just return the raw item, instead of wrapping it with a list, to support weaving one-to-many relationship
    end
  end
end
