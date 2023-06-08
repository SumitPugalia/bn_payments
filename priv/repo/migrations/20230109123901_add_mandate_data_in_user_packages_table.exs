defmodule BnApis.Repo.Migrations.AddMandateDataInUserPackagesTable do
  use Ecto.Migration

  def up do
    alter table(:user_packages) do
      add(:mandate_mode, :string)
      add(:subscription_id, :string)
      add(:mandate_id, :string)
      add(:invoice_id, :string)
    end
  end

  def down do
    alter table(:user_packages) do
      add(:mandate_mode, :string)
      add(:subscription_id, :string)
      add(:mandate_id, :string)
      add(:invoice_id, :string)
    end
  end
end
