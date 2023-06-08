defmodule BnApis.Repo.Migrations.HomeloanCallStatuses do
  use Ecto.Migration

  def change do
    create table(:homeloans_call_lead_statuses) do
      add(:lead_status_id, :integer)
      add(:call_details_id, references(:call_details))

      timestamps()
    end
  end
end
