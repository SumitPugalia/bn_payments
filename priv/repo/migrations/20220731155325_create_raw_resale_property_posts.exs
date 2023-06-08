defmodule BnApis.Repo.Migrations.CreateRawResalePropertyPosts do
  use Ecto.Migration

  def change do
    create table(:raw_resale_property_posts) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :source, :string
      add :price, :integer
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
