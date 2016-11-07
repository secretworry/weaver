defmodule Weaver.BuilderV2.Weave do

  alias Weaver.BuilderV2.Cards

  defmacro weave_one(field, opts) do
    opts = Keyword.merge([type: :one], opts) |> Macro.escape
    quote do
      [target: unquote(field)]
      |> Enum.concat(unquote opts) |> parse(unquote(Macro.escape __CALLER__)) |> Cards.push
    end
  end

  defmacro weave_one(field, opts, do: block) do
    opts = Keyword.merge([type: :one], opts) |> Macro.escape
    quote do
      s = Cards.snapshot
      Cards.pop
      unquote(block)
      children = Cards.pop
      Cards.restore(s)
      [target: unquote(field), children: children]
      |> Enum.concat(unquote opts) |> parse(unquote(Macro.escape __CALLER__)) |> Cards.push
    end
  end

  defmacro weave_many(field, opts) do
    opts = Keyword.merge([type: :many], opts) |> Macro.escape
    quote do
      [target: unquote(field)]
      |> Enum.concat(unquote opts) |> parse(unquote(Macro.escape __CALLER__)) |> Cards.push
    end
  end

  defmacro weave_many(field, opts, do: block) do
    opts = Keyword.merge([type: :many], opts) |> Macro.escape
    quote do
      s = Cards.snapshot
      Cards.pop
      unquote(block)
      children = Cards.pop
      Cards.restore(s)
      [target: unquote(field), children: children]
      |> Enum.concat(unquote opts) |> parse(unquote(Macro.escape __CALLER__)) |> Cards.push
    end
  end

  def parse(opts, env) do
    opts = %{
      provider: Keyword.get(opts, :by),
      collector: Keyword.get(opts, :through),
      weaver: Keyword.get(opts, :with),
      target: Keyword.fetch!(opts, :target),
      type: Keyword.fetch!(opts, :type),
      children: Keyword.get(opts, :children, [])
    }
    opts = [:convert_collector, :expand_provider, :expand_weaver, :inline_v2_weaver] |> Enum.reduce(opts, fn parser, opts ->
      do_parse(parser, opts, env)
    end)
    struct(Weaver.BuilderV2.Card, opts)
  end

  defp do_parse(:convert_collector, %{collector: collector} = opts, _env) do
    case collector do
      nil -> opts
      x when is_list(x) -> %{opts| collector: {Weaver.BuilderV2.RelativeCollector, x}}
      {collector, opts} -> %{opts| collector: {Module.concat([Weaver, BuilderV2, collector]), opts}}
      _ -> raise "Unrecognizable collector #{inspect collector}"
    end
  end

  defp do_parse(:expand_provider, %{provider: provider} = opts, env) do
    case provider do
      nil -> if Map.get(opts, :collector) != nil do
        %{opts | provider: Weaver.CopyProvider}
      else
        opts
      end
      x -> %{opts | provider: Macro.expand(x, env)}
    end
  end

  defp do_parse(:expand_provider, opts, _env) do
    opts
  end


  defp do_parse(:expand_weaver, %{weaver: weaver} = opts, env) do
    case weaver do
      nil -> opts
      x -> %{opts | weaver: Macro.expand(x, env)}
    end
  end

  defp do_parse(:expand_weaver, opts, _env) do
    opts
  end

  defp do_parse(:inline_v2_weaver, %{weaver: weaver} = opts, _env) do
    case weaver do
      nil -> opts
      x -> if function_exported?(x, :cards, 0) do
        %{opts | weaver: nil, children: x.cards}
      else
        opts
      end
    end
  end

  defp do_parse(:inline_v2_weaver, opts, _env) do
    opts
  end
end
