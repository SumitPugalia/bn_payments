defmodule BnApis.Helpers.ErrorMapper do
  def format({:error, :invalid_access}), do: format({:error, "Cannot perform this operation for given input, insufficient permissions"})
  def format({:error, message}), do: %{message: message}
end
