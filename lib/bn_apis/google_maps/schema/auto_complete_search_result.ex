defmodule BnApis.GoogleMaps.Schema.AutoCompleteSearchResult do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :place_key, :string
    field :name, :string
    field :display_address, :string
  end

  @fields [:place_key, :name, :display_address]
  @doc false
  def changeset(searchResult, attrs) do
    searchResult
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end
end
