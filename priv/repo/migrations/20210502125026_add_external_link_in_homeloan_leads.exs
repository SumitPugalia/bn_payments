defmodule BnApis.Repo.Migrations.AddExternalLinkInHomeloanLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:external_link, :string)
    end
  end
end
