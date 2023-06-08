defmodule BnApis.Repo.Migrations.AddUpdationTimeInResaleClientPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_client_posts) do
      add :updation_time, :naive_datetime
    end
  end
end
