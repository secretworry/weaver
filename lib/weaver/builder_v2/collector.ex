defmodule Weaver.BuilderV2.Collector do

  @type context :: {any, Weaver.BuilderV2.Thread.t, any}

  @type opts :: any

  @callback collect(context, opts) :: any
  @callback collect_many(context, opts) :: [any]
end
