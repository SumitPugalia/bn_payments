defmodule BnApis.Repo.Migrations.AddIsClientSideRegistrationSuccessfulToMemberships do
  use Ecto.Migration

  def change do
    alter table(:memberships) do
      add(:is_client_side_registration_successful, :boolean, default: false)
    end
  end
end
