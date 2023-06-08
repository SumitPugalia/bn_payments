defmodule BnApis.Repo.Migrations.AddFcmIdInDeveloperPocCredentials do
  use Ecto.Migration

  def change do
    alter table(:developer_poc_credentials) do
      add :fcm_id, :string
      add :platform, :string
    end
  end
end
