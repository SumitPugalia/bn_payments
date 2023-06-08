defmodule BnApis.Posts.Buckets.Schema.Bucket do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Posts.Buckets.Filters
  alias BnApis.Reasons.Reason
  alias BnApis.Organizations.Broker

  schema "buckets" do
    field :name, :string
    field :number_of_matching_properties, :integer, default: 0
    field :last_seen_at, :integer
    field :expires_at, :integer
    field :archive_at, :integer
    field :new_number_of_matching_properties, :integer, virtual: true, default: 0
    field :archived, :boolean, default: false

    embeds_one(:filters, Filters)
    belongs_to(:broker, Broker)
    belongs_to(:archived_reason, Reason)
    timestamps()
  end

  @fields [:name, :broker_id]
  @editable_fields [:number_of_matching_properties, :last_seen_at, :expires_at, :archive_at, :archived, :archived_reason_id]
  @month 30 * 24 * 60 * 60

  @doc false
  def changeset(bucket, attrs) do
    ## If context doesn't pass expires_at we set it by default to a month ahead
    attrs = Map.put_new(attrs, "expires_at", DateTime.utc_now() |> DateTime.add(@month) |> DateTime.to_unix())

    bucket
    |> cast(attrs, @fields ++ @editable_fields)
    |> cast_embed(:filters)
    |> assoc_constraint(:broker)
    |> assoc_constraint(:archived_reason)
    |> validate_required(@fields ++ [:filters, :expires_at])
  end

  def update_changeset(bucket, attrs) do
    bucket
    |> cast(attrs, @editable_fields)
    |> assoc_constraint(:archived_reason)
    |> validate_all_of([:archived, :archived_reason_id])
  end

  def validate_all_of(%Ecto.Changeset{valid?: true} = changeset, fields) do
    total_found =
      Enum.reduce(fields, 0, fn field, found ->
        if get_change(changeset, field), do: found + 1, else: found
      end)

    if total_found == length(fields) || total_found == 0 do
      changeset
    else
      error = "all of " <> Enum.join(fields, ",") <> " is required"
      add_error(changeset, hd(fields), error)
    end
  end

  def validate_all_of(changeset, _), do: changeset
end
