defmodule BnApis.Repo.Migrations.ModifyEntityIdWhatsappRequests do
  use Ecto.Migration

  def change do
    alter table(:whatsapp_requests) do
      remove :entity_type
      add :entity_type, :integer
    end
  end
end
