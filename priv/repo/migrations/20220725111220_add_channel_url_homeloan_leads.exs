defmodule BnApis.Repo.Migrations.AddChannelUrlHomeloanLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:channel_url, :string)
    end
  end
end
