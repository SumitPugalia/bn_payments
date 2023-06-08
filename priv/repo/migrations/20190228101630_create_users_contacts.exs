defmodule BnApis.Repo.Migrations.CreateUsersContacts do
  use Ecto.Migration

  def change do
    create table(:users_contacts) do
      add :contact_id, :integer
      add :name, :string
      add :phone_number, :string
      add :label, :string
      add :user_id, references(:credentials, on_delete: :nothing)

      timestamps()
    end

    create index(:users_contacts, [:user_id])
  end
end
