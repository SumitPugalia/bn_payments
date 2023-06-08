defmodule BnApis.Posts.Buckets.Filters do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Places.Polygon
  alias BnApis.Posts.PostType
  alias BnApis.Posts.ConfigurationType

  @primary_key false
  embedded_schema do
    field :location_name, :string
    field :post_type, :string
    field :configuration_type, {:array, :string}
    field :building_ids, {:array, Ecto.UUID}
    field :latitude, :string
    field :longitude, :string

    belongs_to(:locality, Polygon)
  end

  @fields [:post_type, :configuration_type, :longitude, :latitude, :locality_id, :location_name, :building_ids]
  def changeset(filters, attrs) do
    filters
    |> cast(attrs, @fields)
    |> validate_required([:post_type, :configuration_type, :location_name])
    |> validate_all_of([:latitude, :longitude])
    |> validate_one_of([:latitude, :locality_id, :building_ids])
    |> validate_inclusion(:post_type, Enum.map(PostType.seed_data(), & &1.name), message: "invalid post type")
    |> validate_length(:configuration_type, min: 1, max: 2)
    |> validate_length(:building_ids, min: 1, max: 5)
    |> validate_subset(:configuration_type, Enum.map(ConfigurationType.seed_data(), & &1.name), message: "invalid configuration type")
  end

  def validate_one_of(%Ecto.Changeset{valid?: true} = changeset, fields) do
    total_found =
      Enum.reduce(fields, 0, fn field, found ->
        if get_change(changeset, field), do: found + 1, else: found
      end)

    case total_found do
      0 ->
        error = "one of " <> (Enum.join(fields, ",") |> String.replace("latitude", "google_place_id")) <> "is required"
        add_error(changeset, :filters, error)

      1 ->
        changeset

      _ ->
        error = "only one of " <> (Enum.join(fields, ",") |> String.replace("latitude", "google_place_id")) <> " is allowed"
        add_error(changeset, :filters, error)
    end
  end

  def validate_one_of(changeset, _), do: changeset

  def validate_all_of(%Ecto.Changeset{valid?: true} = changeset, fields) do
    total_found =
      Enum.reduce(fields, 0, fn field, found ->
        if get_change(changeset, field), do: found + 1, else: found
      end)

    if total_found == length(fields) || total_found == 0 do
      changeset
    else
      error = "all of " <> Enum.join(fields, ",") <> " is required"
      add_error(changeset, :filters, error)
    end
  end

  def validate_all_of(changeset, _), do: changeset
end
