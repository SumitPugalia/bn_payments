defmodule BnApis.Repo.Migrations.AlterCommercialPostFields do
  use Ecto.Migration

  def change do
    alter table(:commercial_property_posts) do
      remove :handover_status
      remove :premise_type
      add :handover_status, {:array, :string}, default: []
      add :premise_type, {:array, :string}, default: []
    end
  end
end
