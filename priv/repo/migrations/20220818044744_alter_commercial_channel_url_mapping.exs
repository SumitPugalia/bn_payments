defmodule BnApis.Repo.Migrations.AlterCommercialChannelUrlMapping do
  use Ecto.Migration

  def change do
    alter table(:commercial_channel_url_mapping) do
      add :user_ids, {:array, :integer}, default: []
    end
  end
end
