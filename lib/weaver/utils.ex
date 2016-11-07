defmodule Weaver.Utils do
  defmodule Lists do
    def map_with(list, map, callback \\ fn _ -> :drop end) do
      Enum.reduce(list, [], fn item, acc ->
        case Map.get(map, item) do
          nil -> case callback.(item) do
            :drop -> acc
            {item} -> [item | acc]
          end
          x -> [x | acc]
        end
      end) |> Enum.reverse
    end
  end
end
