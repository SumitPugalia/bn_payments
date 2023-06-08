defmodule BnApis.Repo.Migrations.AddCreatedByIdInWhatsappChats do
  use Ecto.Migration

  def change do
    alter table(:whatsapp_chats) do
      add :created_by_id, references(:employees_credentials), on_delete: :nothing
    end
  end
end
