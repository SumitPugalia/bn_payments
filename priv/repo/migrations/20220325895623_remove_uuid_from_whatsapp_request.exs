defmodule BnApis.Repo.Migrations.RemoveUuidFromWhatsappRequest do
  use Ecto.Migration

  def change do
    alter table(:whatsapp_requests) do
      remove :uuid
    end
  end
end
