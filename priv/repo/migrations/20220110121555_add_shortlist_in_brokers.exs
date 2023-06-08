defmodule BnApis.Repo.Migrations.AddShortlistInBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add :rental_shortlisted_posts, {:array, :string}, default: []
      add :resale_shortlisted_posts, {:array, :string}, default: []
    end
  end
end
