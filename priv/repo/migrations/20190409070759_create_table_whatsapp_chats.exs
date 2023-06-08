defmodule BnApis.Repo.Migrations.CreateTableWhatsappChats do
  use Ecto.Migration

  def change do
    create table(:whatsapp_chats) do
      add :phone_number, :string, null: false
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :md5_hash, :string
      add :post_module, :string, null: false
      add :post_id, :integer, null: false
      add :chat_text, :string, null: false

      timestamps()
    end

    create unique_index(:whatsapp_chats, [:phone_number, :md5_hash])
  end
end
