defmodule BnApis.Repo.Migrations.AddFieldsInCabOperators do
  use Ecto.Migration

  def change do
    alter table(:cab_operators) do
      add(:business_name, :string)
      add(:owner_name, :string)
      add(:contact_number, :string)
      add(:aadhar_card, :string)
      add(:resident_address, :string)
      add(:office_address, :string)
      add(:gst, :string)
      add(:pan, :string)
      add(:bank_name, :string)
      add(:account_number, :string)
      add(:ifsc, :string)
      add(:commission_percentage, :string)
    end
  end
end
