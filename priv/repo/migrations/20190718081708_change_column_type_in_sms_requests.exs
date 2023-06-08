defmodule BnApis.Repo.Migrations.ChangeColumnTypeInSmsRequests do
  use Ecto.Migration

  def change do
    alter table(:sms_requests) do
      modify :body, :text
    end
  end
end
