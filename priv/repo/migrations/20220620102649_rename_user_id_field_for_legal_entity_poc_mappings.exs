defmodule BnApis.Repo.Migrations.RenameUserIdFieldForLegalEntityPocMappings do
  use Ecto.Migration

  def change do
    rename table(:legal_entity_poc_mappings), :user_id, to: :assigned_by
  end
end
