defmodule BnApis.Repo.Migrations.AddFailedReasonInPayouts do
  use Ecto.Migration

  def change do
    alter table(:payouts) do
      add(:failure_reason, :string)
    end
  end
end
