defmodule BnApis.Repo.Migrations.AddEmailInDevelopers do
  use Ecto.Migration

  def change do
    alter table(:developers) do
      add :email, :string
    end
  end
end
