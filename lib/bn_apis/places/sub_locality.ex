defmodule BnApis.Places.SubLocality do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sub_localities" do
    field :name, :string
    field :uuid, Ecto.UUID, read_after_writes: true

    timestamps()
  end

  @doc false
  def changeset(sub_locality, attrs) do
    sub_locality
    |> cast(attrs, [:uuid, :name])
    |> validate_required([:uuid, :name])
  end
end
