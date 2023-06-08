defmodule BnApis.Repo.Migrations.AddVerticalIdInEmployeeCredential do
  use Ecto.Migration

  def change do
    alter table(:employees_credentials) do
      add(:vertical_id, references(:employees_verticals), null: false, default: 1)
    end
  end
end
