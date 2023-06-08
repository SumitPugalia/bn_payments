defmodule BnApis.Repo.Migrations.AddCallDetailsTable do
  use Ecto.Migration

  def change do
    create table(:call_details) do
      add :tran_id, :string
      add :start_time, :string
      add :end_time, :string
      add :answer_time, :string
      add :customer_number, :string
      add :agent_number, :string
      add :duration, :integer
      add :charge, :float
      add :unsuccessful_call_reason, :string
      add :recording_url, :string

      timestamps()
    end
  end
end
