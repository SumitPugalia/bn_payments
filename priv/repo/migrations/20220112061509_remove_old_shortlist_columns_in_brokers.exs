defmodule BnApis.Repo.Migrations.RemoveOldShortlistColumnsInBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      remove :rental_shortlisted_posts
      remove :resale_shortlisted_posts
    end
  end
end
