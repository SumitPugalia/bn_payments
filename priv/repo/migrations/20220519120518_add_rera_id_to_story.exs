defmodule BnApis.Repo.Migrations.AddReraIdToStory do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :rera_ids, {:array, :string}
    end
  end
end
