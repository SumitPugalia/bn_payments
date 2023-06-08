defmodule BnApis.Repo.Migrations.CreateMatchPlusMemberships do
  use Ecto.Migration

  def change do
    create table(:match_plus_memberships) do
      add(:status_id, :integer, null: false)
      add(:broker_id, references(:brokers), null: false)

      timestamps()
    end
  end
end
