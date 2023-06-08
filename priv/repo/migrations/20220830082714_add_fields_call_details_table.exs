defmodule BnApis.Repo.Migrations.AddFieldsCallDetailsTable do
  use Ecto.Migration

  def change do
    alter table(:call_details) do
      add :lead_id, :integer
      add :call_with, :string
      add :entity_type, :string
      add :call_type, :string
    end
  end
end
