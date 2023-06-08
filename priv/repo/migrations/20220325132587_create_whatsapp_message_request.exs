defmodule BnApis.Repo.Migrations.CreateWhatappMessageRequest do
  use Ecto.Migration

  def change do
    create table(:whatsapp_requests) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :status, :string, null: false
      add :to, :string, null: false
      add :template, :string, null: false
      add :status_code, :string, null: true
      add :status_desc, :string, null: true
      add :message_sid, :string, null: true
      add :template_vars, {:array, :string}, default: []
      add :customer_ref, :string, null: true
      add :message_tag, :string, null: true
      add :conversation_id, :string, null: true

      timestamps()
    end

    create index(:whatsapp_requests, [:to])
    create index(:whatsapp_requests, [:template])
    create index(:whatsapp_requests, [:message_sid])
  end
end
