defmodule BnApis.Repo.Migrations.CreateHomeloanLeadStatuses do
  use Ecto.Migration

  def change do
    create table(:homeloan_lead_statuses) do
      add(:status_id, :integer, null: false)
      add(:bank_ids, {:array, :integer})
      add(:amount, :integer)
      add(:homeloan_lead_id, references(:homeloan_leads), null: false)
      add(:employee_credential_id, references(:employees_credentials))
      timestamps()
    end
  end
end
