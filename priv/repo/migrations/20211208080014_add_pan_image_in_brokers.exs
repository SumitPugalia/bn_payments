defmodule BnApis.Repo.Migrations.AddPanImageInBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add :pan_image, :map
    end
  end
end
