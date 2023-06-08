defmodule BnApis.Repo.Migrations.AddCallLogTimeToCallLog do
  use Ecto.Migration

  def change do
    alter table(:call_logs) do
      add :time_of_call, :naive_datetime
    end
  end
end
