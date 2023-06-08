defmodule BnApis.Repo.Migrations.AddUpdationTimeInRentalClientPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_client_posts) do
      add :updation_time, :naive_datetime
    end
  end
end
