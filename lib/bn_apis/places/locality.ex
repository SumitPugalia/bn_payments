defmodule BnApis.Places.Locality do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Places.Locality
  alias BnApis.Repo

  @localities_per_page 5

  schema "localities" do
    field :name, :string
    field :google_place_id, :string
    field :display_address, :string
    field :uuid, Ecto.UUID, read_after_writes: true

    timestamps()
  end

  @fields [:name, :google_place_id, :display_address]

  @doc false
  def changeset(locality, attrs) do
    locality
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end

  def changeset(attrs) do
    %Locality{}
    |> changeset(attrs)
  end

  def get_or_create_locality(params) do
    locality = Locality |> Repo.get_by(google_place_id: params.google_place_id)

    case locality do
      nil ->
        Locality.changeset(params) |> Repo.insert()

      _ ->
        {:ok, locality}
    end
  end

  def search_locality_query(search_text) do
    modified_search_text = "%" <> search_text <> "%"

    Locality
    # |> where(delete: false)
    |> where([l], ilike(l.name, ^modified_search_text))
    |> order_by([l], asc: fragment("lower(?) <-> ?", l.name, ^search_text))
    |> select(
      [l],
      %{
        id: l.id,
        uuid: l.uuid,
        name: l.name,
        display_address: l.display_address,
        google_place_id: l.google_place_id
      }
    )
    |> limit(@localities_per_page)
  end
end
