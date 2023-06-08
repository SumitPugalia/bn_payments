defmodule BnApis.Developers.Developer do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Stories.Story
  alias BnApis.Developers.{MicroMarket, Project}
  alias BnApis.Developers.Developer

  @developers_per_page 10

  schema "developers" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :logo_url, :string
    field :name, :string
    field :email, :string

    belongs_to :micro_market, MicroMarket
    has_many :stories, Story
    has_many :projects, Project
    timestamps()
  end

  @required [:name, :email, :logo_url]
  @optional [:uuid]

  def changeset(developer, attrs) do
    developer
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:email, name: :developers_email_index, message: "Developer email already taken")
  end

  def search_developer_query(search_text, exclude_developer_uuids) do
    modified_search_text = "%" <> search_text <> "%"

    Developer
    |> where([dev], dev.uuid not in ^exclude_developer_uuids)
    |> where([dev], ilike(dev.name, ^modified_search_text))
    |> order_by([dev], fragment("lower(?) <-> ?", dev.name, ^search_text))
    |> limit(@developers_per_page)
    |> select(
      [dev],
      %{
        id: dev.id,
        uuid: dev.uuid,
        name: dev.name,
        email: dev.email
      }
    )
  end
end
