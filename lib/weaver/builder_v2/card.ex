defmodule Weaver.BuilderV2.Card do

  @type card_type :: :many | :one

  @type provider :: atom | nil

  @type collector :: {atom, any} | [atom] | nil

  @type t :: %__MODULE__{type: card_type, target: atom, provider: provider, collector: collector, weaver: Weaver.t | nil, children: [t]}

  defstruct type: nil, target: nil, provider: nil, collector: nil, weaver: nil, children: []
end
