defmodule BnApis.Repo.Migrations.AddOtherProjectNamesInCabBookingRequests do
  use Ecto.Migration

  def change do
    alter table(:cab_booking_requests) do
      add :other_project_names, {:array, :string}
    end
  end
end
