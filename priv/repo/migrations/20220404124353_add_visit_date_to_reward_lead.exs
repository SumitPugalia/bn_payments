defmodule BnApis.Repo.Migrations.AddVisitDateToRewardLead do
  use Ecto.Migration

  def change do
    alter table(:rewards_leads) do
      add :visit_date, :naive_datetime
    end
  end
end
