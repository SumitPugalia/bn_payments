defmodule BnApis.Repo.Migrations.ModifyShortlistInBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add :shortlisted_rental_posts, {:array, :map}, default: []
      add :shortlisted_resale_posts, {:array, :map}, default: []
    end
  end
end
