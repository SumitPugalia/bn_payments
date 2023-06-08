defmodule BnApis.Repo.Migrations.CreateFeedbacksSessions do
  use Ecto.Migration

  def change do
    create table(:feedbacks_sessions) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :initiated_by_id, references(:credentials, on_delete: :nothing)
      add :source, :map

      timestamps()
    end

    create index(:feedbacks_sessions, [:initiated_by_id])
  end
end
