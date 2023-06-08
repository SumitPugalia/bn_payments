defmodule BnApis.Repo.Migrations.AddIndexOnWhatsappRequest do
  use Ecto.Migration

  def change do
    create index(:whatsapp_requests, [:entity_type])
  end
end
