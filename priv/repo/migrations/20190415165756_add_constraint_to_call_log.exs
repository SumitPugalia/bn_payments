defmodule BnApis.Repo.Migrations.AddConstraintToCallLog do
  use Ecto.Migration

  def change do
    create unique_index(:call_logs, [:user_id, :call_log_id], name: :log_pair_constraint)
  end
end
