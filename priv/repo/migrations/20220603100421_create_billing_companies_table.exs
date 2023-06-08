defmodule BnApis.Repo.Migrations.CreateBillingCompaniesTable do
  use Ecto.Migration

  def change do
    create table(:billing_companies) do
      add(:uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false)
      add(:name, :string, null: false)
      add(:address, :string)
      add(:place_of_supply, :string, null: false)
      add(:company_type, :string, null: false)
      add(:email, :string)
      add(:gst, :string, null: false)
      add(:pan, :string, null: false)
      add(:rera_id, :string, null: false)
      add(:signature, :string)
      add(:bill_to_state, :string)
      add(:bill_to_pincode, :integer)
      add(:bill_to_city, :string)
      add(:active, :boolean, default: true)

      timestamps()
    end
  end
end
