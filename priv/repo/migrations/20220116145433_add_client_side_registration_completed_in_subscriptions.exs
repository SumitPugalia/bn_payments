defmodule BnApis.Repo.Migrations.AddClientSideRegistrationCompletedInSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:subscriptions) do
      add(:is_client_side_registration_successful, :boolean, default: false)
    end
  end
end
