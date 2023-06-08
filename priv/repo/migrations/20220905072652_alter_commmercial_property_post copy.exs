defmodule BnApis.Repo.Migrations.AlterCommmercialPropertyPost do
  use Ecto.Migration

  def change do
    alter table(:commercial_property_posts) do
      add :assigned_manager_ids, {:array, :integer}, default: []
    end
  end
end
