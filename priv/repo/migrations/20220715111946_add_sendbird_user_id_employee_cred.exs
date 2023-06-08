defmodule BnApis.Repo.Migrations.AddSendbirdUserIdEmployeeCred do
  use Ecto.Migration

  def change do
    alter table(:employees_credentials) do
      add :sendbird_user_id, :string
    end
  end
end
