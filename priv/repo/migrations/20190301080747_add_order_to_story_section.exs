defmodule BnApis.Repo.Migrations.AddOrderToStorySection do
  use Ecto.Migration

  def change do
    alter table(:stories_sections) do
      # , null: false
      add :order, :integer
    end
  end
end
