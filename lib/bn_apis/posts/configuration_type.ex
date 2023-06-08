defmodule BnApis.Posts.ConfigurationType do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Helpers.Redis
  alias BnApis.Repo

  @studio %{id: 1, name: "Studio / 1 RK"}
  @bhk_1 %{id: 2, name: "1 BHK"}
  @bhk_2 %{id: 3, name: "2 BHK"}
  @bhk_3 %{id: 4, name: "3 BHK"}
  @bhk_4_plus %{id: 5, name: "4+ BHK"}
  @bhk_1_5 %{id: 6, name: "1.5 BHK"}
  @bhk_2_5 %{id: 7, name: "2.5 BHK"}
  @bhk_3_5 %{id: 8, name: "3.5 BHK"}
  @bhk_4 %{id: 9, name: "4 BHK"}
  @plot %{id: 10, name: "Plot"}
  @villa %{id: 11, name: "Villa"}
  @commercial %{id: 12, name: "Commercial"}
  @office %{id: 13, name: "Office"}
  @farmland %{id: 14, name: "Farmland"}
  @commercial_fractional %{id: 15, name: "Commercial-Fractional"}

  def seed_data do
    [
      @studio,
      @bhk_1,
      @bhk_1_5,
      @bhk_2,
      @bhk_2_5,
      @bhk_3,
      @bhk_3_5,
      @bhk_4,
      @bhk_4_plus,
      @plot,
      @villa,
      @commercial,
      @office,
      @farmland,
      @commercial_fractional
    ]
  end

  @primary_key false
  schema "posts_configuration_types" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(configuration_type, params) do
    configuration_type
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def studio, do: @studio
  def bhk_1, do: @bhk_1
  def bhk_2, do: @bhk_2
  def bhk_3, do: @bhk_3
  def bhk_4, do: @bhk_4
  def bhk_4_plus, do: @bhk_4_plus
  def bhk_1_5, do: @bhk_1_5
  def bhk_2_5, do: @bhk_2_5
  def bhk_3_5, do: @bhk_3_5
  def plot, do: @plot
  def villa, do: @villa
  def commercial, do: @commercial
  def office, do: @office
  def farmland, do: @farmland
  def commercial_fractional, do: @commercial_fractional

  def get_by_id(id) when is_binary(id) do
    id = id |> String.to_integer()
    get_by_id(id)
  end

  def get_by_id(id) do
    seed_data()
    |> Enum.filter(&(&1.id == id))
    |> List.first()
  end

  def get_by_name(name) do
    seed_data()
    |> Enum.filter(&(&1.name == name))
    |> List.first()
  end

  def configuration_types_cache() do
    case Redis.q(["GET", "posts_configuration_types"]) do
      {:ok, nil} ->
        configuration_types = Repo.all(__MODULE__)

        Redis.q(["SET", "posts_configuration_types", :erlang.term_to_binary(configuration_types)])
        configuration_types

      {:ok, data} ->
        :erlang.binary_to_term(data)
    end
  end
end
