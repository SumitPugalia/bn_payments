defmodule BnApis.Repo.Migrations.AddInvalidReasonToTransactionData do
  use Ecto.Migration

  def change do
    alter table(:transactions_data) do
      add :invalid_reason, :text
    end
  end
end
