defmodule Weaver.CopyProvider do

  def find(ids) when is_list(ids) do
    Enum.reduce(ids, Map.new, & Map.put(&2, &1, &1))
  end
end
