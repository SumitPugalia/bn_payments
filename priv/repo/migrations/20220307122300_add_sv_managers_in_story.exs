defmodule BnApis.Repo.Migrations.AddSvManagersInStory do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add(:sv_business_development_manager_id, references(:employees_credentials), null: true)
      add(:sv_implementation_manager_id, references(:employees_credentials), null: true)
      add(:sv_market_head_id, references(:employees_credentials), null: true)
      add(:sv_cluster_head_id, references(:employees_credentials), null: true)
      add(:sv_account_manager_id, references(:employees_credentials), null: true)
    end
  end
end
