defmodule BnApis.Repo.Migrations.AddOrgJoiningRequestsTable do
  use Ecto.Migration

  def change do
    create table(:org_joining_requests) do
      add(:requestor_cred_id, references(:credentials), null: false)
      add(:organization_id, references(:organizations), null: false)
      add(:status, :string, null: false)
      add(:processed_by_cred_id, references(:credentials))
      add(:active, :boolean, default: true)

      timestamps()
    end

    create(
      unique_index(
        :org_joining_requests,
        [:requestor_cred_id, :organization_id, :active],
        where: "active = true",
        name: :requestor_org_unique_index
      )
    )

    create index(:org_joining_requests, [:status])
    create index(:org_joining_requests, [:organization_id])
    create index(:org_joining_requests, [:processed_by_cred_id])
  end
end
