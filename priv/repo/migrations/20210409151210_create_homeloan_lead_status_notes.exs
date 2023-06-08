defmodule BnApis.Repo.Migrations.CreateHomeloanLeadStatusNotes do
  use Ecto.Migration

  def change do
    create table(:homeloan_lead_status_notes) do
      add(:note, :text, null: false)

      add(:homeloan_lead_status_id, references(:homeloan_lead_statuses), null: false)

      add(:employee_credential_id, references(:employees_credentials))

      timestamps()
    end
  end
end
