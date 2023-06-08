defmodule BnApis.Accounts.ColorCode do
  use Ecto.Schema

  @green %{id: 1, name: "Green", color: "#008000"}
  @yellow %{id: 2, name: "Yellow", color: "#FFFF00"}
  @red %{id: 3, name: "Red", color: "#FF0000"}

  def seed_data do
    [
      @green,
      @yellow,
      @red
    ]
  end

  def green do
    @green
  end

  def yellow do
    @yellow
  end

  def red do
    @red
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
