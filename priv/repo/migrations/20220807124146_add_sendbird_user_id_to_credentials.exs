defmodule BnApis.Repo.Migrations.AddSendbirdUserIdToCredentials do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add(:sendbird_user_id, :string)
    end
  end
end
