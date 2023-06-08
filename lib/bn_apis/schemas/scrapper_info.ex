defmodule BnApis.Schemas.ScrapperInfo do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo

  @field ~w(name date offset)a

  schema "scrap_info" do
    field(:name, :string)
    field(:date, :date)
    field(:offset, :string)
  end

  def new(params), do: changeset(%__MODULE__{}, params)

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> cast(params, @field)
    |> validate_required(@field)
  end

  def get_scrap_info(scrapper_name) do
    __MODULE__
    |> where([s], s.name == ^scrapper_name)
    |> order_by([s], desc: s.date)
    |> limit(1)
    |> Repo.one()
  end

  def update_scrape_info(%__MODULE__{} = struct, params) do
    struct
    |> changeset(params)
    |> Repo.update()
  end

  def insert(params), do: Repo.insert(new(params))
end
