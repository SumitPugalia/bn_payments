defmodule BnApis.Repo.Migrations.AddLogoUrlInBanks do
  use Ecto.Migration

  def change do
    alter table(:homeloan_banks) do
      add(:logo_url, :string)
    end
  end
end
