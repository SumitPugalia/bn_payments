defmodule BnApis.Repo.Migrations.AddDocsInHomeloanLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:docs, {:array, :jsonb})
    end
  end
end
