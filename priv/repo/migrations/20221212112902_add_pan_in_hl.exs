defmodule BnApis.Repo.Migrations.AddLanInHl do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:pan, :string)
      add(:active, :boolean, default: true)
    end

    create unique_index(:homeloan_leads, :pan,
             where: "active = true",
             name: :unique_pan_active_leads
           )
  end
end
