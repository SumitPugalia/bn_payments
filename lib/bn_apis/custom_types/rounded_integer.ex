defmodule BnApis.CustomTypes.RoundedInteger do
  @behaviour Ecto.Type

  def type, do: :integer

  ## convert string value to integer
  def cast(value) when is_binary(value) do
    int_value =
      case Float.parse(value) do
        :error -> 0
        {float_value, _} -> round(float_value)
      end

    {:ok, int_value}
  end

  ## convert float value to integer
  def cast(value) when is_float(value), do: {:ok, round(value)}
  def cast(value), do: {:ok, value}

  ## callback functions implementation
  def load(data), do: Ecto.Type.load(:integer, data)
  def dump(data), do: Ecto.Type.dump(:integer, data)
  def embed_as(_), do: :self
  def equal?(lhs, rhs), do: cast(lhs) == cast(rhs)
end
