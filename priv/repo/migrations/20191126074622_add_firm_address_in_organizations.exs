defmodule BnApis.Repo.Migrations.AddFirmAddressInOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :firm_address, :string
      add :place_id, :string
    end
  end
end
