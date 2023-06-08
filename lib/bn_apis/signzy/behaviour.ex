defmodule BnApis.Signzy.Behaviour do
  @callback validate_pan_number(map(), String.t(), String.t()) :: {:ok, boolean()} | {:error, any(), any()}
end
