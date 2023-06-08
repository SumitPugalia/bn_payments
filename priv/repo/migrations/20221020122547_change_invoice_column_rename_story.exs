defmodule BnApis.Repo.Migrations.ChangeInvoiceColumnRenameStory do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE invoices DROP CONSTRAINT invoices_story_id_fkey"
    rename table(:invoices), :story_id, to: :entity_id

    alter table(:invoices) do
      add :entity_type, :string
    end

    create index(:invoices, [:entity_type])

    execute(
      "UPDATE invoices set entity_type = 'stories' where entity_type is NULL and entity_id is not NULL;"
    )
  end

  def down do
    rename table(:invoices), :entity_id, to: :story_id
    drop index(:invoices, [:entity_type])

    alter table(:invoices) do
      modify :story_id, references(:stories)
      remove :entity_type, :string
    end
  end
end
