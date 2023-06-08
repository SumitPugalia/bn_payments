defmodule BnApis.Repo.Migrations.AddFcmIdToCredential do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :fcm_id, :string
    end

    create index(:credentials, [:fcm_id])
  end
end
