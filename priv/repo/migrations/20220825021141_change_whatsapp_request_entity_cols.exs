defmodule BnApis.Repo.Migrations.ChangeWhatsappRequestEntityCols do
  use Ecto.Migration

  def change do
    alter table(:whatsapp_requests) do
      remove :entity_type
      add :entity_type, :string
      remove :entity_id
      add :entity_id, :integer
    end
  end
end
