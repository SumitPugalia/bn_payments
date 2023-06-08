defmodule BnApis.Posts.PostType do
  use Ecto.Schema

  @rent %{id: 1, name: "Rent"}
  @resale %{id: 2, name: "Resale"}

  def seed_data do
    [
      @rent,
      @resale
    ]
  end

  def rent do
    @rent
  end

  def resale do
    @resale
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
end
