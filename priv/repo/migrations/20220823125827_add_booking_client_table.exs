defmodule BnApis.Repo.Migrations.AddBookingClientTable do
  use Ecto.Migration

  def change do
    create table(:booking_client) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :pan_number, :string
      add :pan_card_image, :string
      add :permanent_address, :string
      add :address_proof, :string

      timestamps()
    end
  end
end
