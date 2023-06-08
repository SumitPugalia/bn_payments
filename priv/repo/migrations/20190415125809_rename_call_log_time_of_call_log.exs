defmodule BnApis.Repo.Migrations.RenameCallLogTimeOfCallLog do
  use Ecto.Migration

  def change do
    alter table(:call_logs) do
      remove :start_time
    end

    rename table("call_logs"), :time_of_call, to: :start_time
  end
end
