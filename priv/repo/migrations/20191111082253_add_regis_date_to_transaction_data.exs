defmodule BnApis.Repo.Migrations.AddRegisDateToTransactionData do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :registration_date, :naive_datetime
    end
  end
end
