defmodule BnApis.Repo.Migrations.AddDsaFieldsInBroker do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add(:email, :string)
      add(:role_type_id, :integer)
      add(:homeloans_tnc_agreed, :boolean, default: false)
      add(:hl_commission_status, :integer)
      add(:hl_commission_rej_reason, :string)
    end
  end
end
