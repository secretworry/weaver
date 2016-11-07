defmodule Weaver.BuilderV2 do
  defmacro __using__(_opts) do
    quote do
      import Weaver.BuilderV2.Cards
      import Weaver.BuilderV2.Weave

      alias Weaver.BuilderV2.Cards

      @cards []

      @before_compile unquote(__MODULE__)

      def weave(items) do
        weave_builder_call(items)
      end

      def cards do
        do_get_cards
      end

      defoverridable [weave: 1]
    end
  end

  defmacro __before_compile__(env) do
    item = quote do: item
    cards = Module.get_attribute(env.module, :cards)
    if Enum.empty?(cards) do
      raise "No weaver is defined in #{inspect env.module}"
    end
    call = Weaver.BuilderV2.Cards.quote_cards_call(cards, item)
    quote do
      defp weave_builder_call(unquote(item)) do
        unquote(call)
      end

      defp do_get_cards do
        unquote(Macro.escape cards)
      end
    end
  end
end
