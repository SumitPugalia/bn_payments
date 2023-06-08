defmodule BnApis.Repo.Migrations.RemoveWhatappMessageRequestIndex do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:whatsapp_requests, [:status])
  end
end
