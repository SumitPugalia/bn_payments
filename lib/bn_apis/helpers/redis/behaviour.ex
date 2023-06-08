defmodule BnApis.Helpers.Redis.Behaviour do
  @callback q(list(String.t())) :: {:ok, list(String.t())}
end
