defmodule BnApis.Repo.Migrations.ModifyWhatsappRequests do
  use Ecto.Migration

  def change do
    alter table(:whatsapp_requests) do
      add :entity_type, :string
      add :entity_id, :string
    end
  end
end
