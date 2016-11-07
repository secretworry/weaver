defmodule Weaver.Builder.Shed do
  @type knot :: atom | binary | [knot]

  @typedoc """
  The name borrowed from weaving, its the threads that other threads pass them to form cloth.
  It's a kind of path that data pass through
  """
  @type weft :: [knot]

  @typedoc """
  Borrowed from weaving. defined how the data are collected and assembled
  """
  @type tablet :: {weft, weft}

  @type t :: %__MODULE__{provider: atom, tablets: [tablet], converter: (any -> any) | none, id_converter: (any -> any) | none}

  defstruct provider: nil, tablets: [], converter: nil, id_converter: nil
end
