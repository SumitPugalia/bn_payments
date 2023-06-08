defmodule Mix.Tasks.Migrate.CredentialsFromBrokerOrganizations do
  use Mix.Task

  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.BrokerOrganization
  import Ecto.Query

  @shortdoc "Populate Credentials from Broker Organization"
  @moduledoc """
    Run this task before removing
    brokers_organizations table

    Keep only active onces in Credentials table
    Move rest to Invite Table
  """

  def run(_args) do
    Mix.Task.run("app.start", [])

    BrokerOrganization
    |> where(active: true)
    |> Repo.all()
    |> Enum.each(&update_in_credential/1)
  end

  def update_in_credential(%BrokerOrganization{} = brokers_organization) do
    %BrokerOrganization{
      active: active,
      last_active_at: last_active_at,
      organization_id: organization_id,
      broker_role_id: broker_role_id,
      broker_id: broker_id
    } = brokers_organization

    case Credential |> where([s], s.broker_id == ^broker_id) |> Repo.one() do
      nil ->
        "user not found"

      credential ->
        change_params = %{
          last_active_at: last_active_at,
          organization_id: organization_id,
          broker_role_id: broker_role_id,
          active: active
        }

        credential |> Credential.changeset(change_params) |> Repo.update()
    end
  end

  def update_in_credential(_bo), do: false
end
