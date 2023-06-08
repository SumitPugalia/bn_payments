defmodule BnApis.Repo.Migrations.CreateRawRentalPropertyPosts do
  use Ecto.Migration

  def change do
    create table(:raw_rental_property_posts) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :source, :string
      add :rent_expected, :integer
      add :name, :string
      add :country_code, :string
      add :phone, :string
      add :building, :string
      add :city, :string
      add :address, :string
      add :pincode, :string
      add :configuration, :string
      add :carpet_area, :integer
      add :car_parkings, :integer
      add :furnishing_type, :string
      add :available_from, :naive_datetime
      add :is_bachelor_allowed, :boolean, default: false
      add :notes, :string
      add :token_id, :string
      add :disposition, :string
      add :reason, :string
      add :campaign_id, :string
      add :slash_reference_id, :string
      add :pushed_to_slash, :boolean, default: false
      add(:employee_credentials_id, references(:employees_credentials), null: true)
      timestamps()
    end
  end
end
