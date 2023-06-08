defmodule BnApis.Buildings.BuildingEnums do
  use Ecto.Schema

  # building types
  @commercial "commercial"
  @residential "residential"

  @building_type_enum %{
    1 => %{
      "id" => 1,
      "identifier" => @residential,
      "display_name" => @residential
    },
    2 => %{
      "id" => 2,
      "identifier" => @commercial,
      "display_name" => @commercial
    }
  }

  @building_grade_enum %{
    1 => %{
      "id" => 1,
      "identifier" => "A+",
      "display_name" => "A+"
    },
    2 => %{
      "id" => 2,
      "identifier" => "A",
      "display_name" => "A"
    },
    3 => %{
      "id" => 3,
      "identifier" => "B+",
      "display_name" => "B+"
    },
    4 => %{
      "id" => 4,
      "identifier" => "B",
      "display_name" => "B"
    },
    5 => %{
      "id" => 5,
      "identifier" => "C",
      "display_name" => "C"
    }
  }

  @building_type_id_mapping Enum.into(@building_type_enum, %{}, &{Map.get(elem(&1, 1), "identifier"), elem(&1, 0)})
  @building_grade_id_mapping Enum.into(@building_grade_enum, %{}, &{Map.get(elem(&1, 1), "identifier"), elem(&1, 0)})

  def commercial() do
    @commercial
  end

  def residential() do
    @residential
  end

  def building_type_enum() do
    @building_type_enum
  end

  def building_grade_enum() do
    @building_grade_enum
  end

  def get_building_type_id(nil), do: nil

  def get_building_type_id(building_type) do
    @building_type_id_mapping[building_type]
  end

  def get_building_grade_id(nil), do: nil

  def get_building_grade_id(building_grade) do
    @building_grade_id_mapping[building_grade]
  end

  def get_building_type_from_id(nil), do: nil

  def get_building_type_from_id(id) do
    @building_type_enum[id]["identifier"]
  end

  def get_building_grade_from_id(nil), do: nil

  def get_building_grade_from_id(id) do
    @building_grade_enum[id]["identifier"]
  end

  def get_all_enums() do
    %{
      "building_grades" => @building_grade_enum,
      "building_types" => @building_type_enum
    }
  end
end
