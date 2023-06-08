defmodule BnApis.Posts.PostSubType do
  use Ecto.Schema

  @property %{id: 1, name: "Property"}
  @client %{id: 2, name: "Client"}

  def seed_data do
    [
      @property,
      @client
    ]
  end

  def property do
    @property
  end

  def client do
    @client
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
