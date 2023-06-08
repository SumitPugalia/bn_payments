defmodule BnApis.Repo.Migrations.AddUpdationTimeInRentalPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_property_posts) do
      add :updation_time, :naive_datetime
    end
  end
end
