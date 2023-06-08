defmodule BnApis.Repo.Migrations.RemoveMd5HashFromWhatsapp do
  use Ecto.Migration

  def change do
    alter table(:whatsapp_chats) do
      remove :md5_hash
    end
  end
end
