defmodule BnApis.BookingRewards.Schema.BookingClient do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.BookingRewards.Schema.{BookingClient}
  alias BnApis.Helpers.S3Helper
  alias BnApis.Helpers.AuditedRepo

  schema "booking_client" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:name, :string)
    field(:pan_number, :string)
    field(:pan_card_image, :string)
    field(:permanent_address, :string)
    field(:address_proof, :string)

    timestamps()
  end

  @required_fields [
    :name
  ]

  @optional_fields [
    :pan_number,
    :pan_card_image,
    :permanent_address,
    :address_proof
  ]

  def changeset(booking_client, attrs) do
    booking_client
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_pan()
  end

  def create(params, user_map) do
    %BookingClient{}
    |> changeset(params)
    |> AuditedRepo.insert(user_map)
  end

  def get_by_id(id) do
    Repo.get!(BookingClient, id)
  end

  def update(booking_client, params, user_map) do
    booking_client
    |> changeset(params)
    |> AuditedRepo.update(user_map)
  end

  def update_or_insert(booking_client, params, user_map) do
    if is_nil(booking_client) do
      create(params, user_map)
    else
      update(booking_client, params, user_map)
    end
  end

  defp validate_pan(changeset) do
    pan = get_field(changeset, :pan_number)

    if not is_nil(pan) and String.length(pan) == 10 do
      valid_pan? = String.match?(pan, ~r/[A-Z]{5}[0-9]{4}[A-Z]{1}/i)
      if valid_pan?, do: changeset, else: add_error(changeset, :pan_number, "PAN is invalid.")
    else
      if is_nil(pan), do: changeset, else: add_error(changeset, :pan_number, "PAN is of an invalid length.")
    end
  end

  def to_map(nil), do: nil

  def to_map(%__MODULE__{} = booking_client) do
    %{
      name: booking_client.name,
      pan_number: booking_client.pan_number,
      pan_card_image: S3Helper.get_imgix_url(booking_client.pan_card_image),
      permanent_address: booking_client.permanent_address,
      address_proof: S3Helper.get_imgix_url(booking_client.address_proof)
    }
  end
end
