defmodule BnApis.Organizations.Schemas.OrgJoiningRequest do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.Organization

  schema "org_joining_requests" do
    field(:status, Ecto.Enum, values: [:approval_pending, :approved, :rejected, :deleted])
    field(:active, :boolean, default: true)

    belongs_to(:requestor_cred, Credential)
    belongs_to(:organization, Organization)
    belongs_to(:processed_by_cred, Credential)

    timestamps()
  end

  @fields [
    :status,
    :active,
    :requestor_cred_id,
    :organization_id,
    :processed_by_cred_id
  ]

  @required_fields [
    :status,
    :requestor_cred_id,
    :organization_id
  ]

  @valid_status_change %{
    nil => [:approval_pending, :approved],
    :approval_pending => [:approved, :rejected, :deleted],
    :approved => [],
    :rejected => [:deleted],
    :deleted => []
  }

  @duplicate_request_error_message "A joining request to the same organization already exists for the requestor"

  @doc false
  def changeset(joining_request, attrs \\ %{}) do
    old_status = Map.get(joining_request, :status)

    joining_request
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_status_change(old_status)
    |> unique_constraint(:requestor_cred_id,
      name: :requestor_org_unique_index,
      message: @duplicate_request_error_message
    )
    |> foreign_key_constraint(:requestor_cred_id)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:processed_by_cred_id)
  end

  defp validate_status_change(changeset = %{valid?: true}, old_status) do
    new_status = get_field(changeset, :status) |> parse_request_status()

    if valid_status_change(old_status, new_status),
      do: changeset,
      else: add_error(changeset, :status, "Cannot change status from #{old_status} to #{new_status}")
  end

  defp validate_status_change(changeset, _old_status), do: changeset

  defp parse_request_status(nil), do: nil
  defp parse_request_status(status) when is_binary(status), do: String.to_atom(status)
  defp parse_request_status(status), do: status

  defp valid_status_change(status, status) when not is_nil(status), do: true
  defp valid_status_change(old_status, new_status), do: @valid_status_change[old_status] |> Enum.any?(&(&1 == new_status))
end
