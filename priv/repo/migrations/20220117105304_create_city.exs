defmodule BnApis.Repo.Migrations.CreateCity do
  use Ecto.Migration

  def change do
    create table(:cities) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add(:feature_flags, :map, default: %{})

      timestamps()
    end
  end
end
