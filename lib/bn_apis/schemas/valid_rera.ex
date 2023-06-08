defmodule BnApis.Schemas.ValidRera do
  use Ecto.Schema
  import Ecto.Changeset

  schema "valid_reras" do
    field(:rera_id, :string)
    field(:rera_name, :string)
    field(:rera_file, :string)
    timestamps()
  end

  @fields [:rera_id, :rera_name, :rera_file]
  @required_fields @fields

  @doc false
  def changeset(valid_rera, attrs \\ %{}) do
    valid_rera
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:rera_id, name: :unique_rera_index, message: "A rera_id with same rera_name already exits.")
    |> format_changeset_response()
  end

  ## Private APIs

  defp format_changeset_response(%Ecto.Changeset{valid?: true} = changeset), do: {:ok, changeset}

  defp format_changeset_response(changeset), do: {:error, changeset}
end
