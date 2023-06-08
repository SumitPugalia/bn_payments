defmodule BnApisWeb.AssistedPropertyController do
  use BnApisWeb, :controller

  alias BnApis.Helpers.Connection
  alias BnApis.AssistedProperty
  alias BnApis.Posts.ResalePropertyPost
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Accounts.EmployeeRole

  require Logger

  action_fallback(BnApisWeb.FallbackController)

  ###################################################################
  # post -> admin/posts/:post_type/property/owner/:post_uuid/assign_manager
  ###################################################################
  def assign_manager(
        conn,
        _params = %{
          "post_type" => "resale",
          "post_uuid" => post_uuid,
          "assign_to" => employee_credential_uuid
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with employee_credential_id when not is_nil(employee_credential_id) <- employee_credential_uuid |> EmployeeCredential.get_id_from_uuid(),
         {:post_check, post} when not is_nil(post) <- {:post_check, ResalePropertyPost.get_post_by(%{uuid: post_uuid, uploader_type: "owner", archived: false})},
         {:assisted_property_check, assisted_post} when is_nil(assisted_post) <-
           {:assisted_property_check, AssistedProperty.get_assisted_property_by(%{resale_property_post_id: post.id, is_active: true})},
         {:ok, building_id} <-
           AssistedProperty.create_assisted_property(:resale, %{
             building_id: post.building_id,
             status: :assigned,
             assisted_by_id: employee_credential_id,
             assigned_by_id: logged_in_user.user_id,
             updated_by_id: logged_in_user.user_id
           }) do
      conn
      |> put_status(:ok)
      |> json(%{building_id: building_id})
    else
      {:post_check, nil} -> conn |> put_status(:bad_request) |> json(%{message: "invalid post"})
      {:assisted_property_check, _assisted_post} -> conn |> put_status(:bad_request) |> json(%{message: "property is already being assisted"})
      {:error, msg} -> conn |> put_status(:bad_request) |> json(%{message: msg})
    end
  end

  def assign_manager(conn, _params), do: conn |> put_status(:bad_request) |> json(%{message: "Invalid Params"})

  ##################################################################
  # post -> admin/posts/:post_type/property/owner/assisted_property
  # filters supported:
  #   - p (page number)
  #   - size (page size)
  #   - status
  #   - building_id
  #   - assigned_by_id
  #   - assisted_by_id
  ###################################################################

  def fetch_assisted_property(conn, params = %{"post_type" => "resale"}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    params = update_params_based_on_employee_role(params, logged_in_user.employee_role_id, logged_in_user.user_id)

    with {:ok, assisted_properties, has_more_properties?} <- AssistedProperty.fetch_assisted_properties(:resale, params) do
      conn
      |> put_status(:ok)
      |> json(%{assisted_properties: assisted_properties, has_more_properties: has_more_properties?})
    end
  end

  def fetch_assisted_property(conn, _params), do: conn |> put_status(:bad_request) |> json(%{message: "Invalid Params"})

  ##################################################################
  # post -> admin/posts/:post_type/property/owner/:post_uuid/update_assisted_property
  # to update assisted_property_post_agreements column values
  ###################################################################

  def update_assisted_property(conn, params = %{"assisted_property_post_agreement_uuid" => assisted_property_post_agreement_uuid}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    employee_role_id = logged_in_user.employee_role_id

    with {:ok, _assisted_property} <- AssistedProperty.update_assisted_properties(assisted_property_post_agreement_uuid, employee_role_id, logged_in_user.user_id, params) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Assisted Property is updated successfully"})
    end
  end

  def update_assisted_property(conn, _params), do: conn |> put_status(:bad_request) |> json(%{message: "Invalid Params"})

  ###################################################################
  # get -> admin/posts/:post_type/property/owner/assisted_property/overview
  ###################################################################
  def overview(conn, _params = %{"post_type" => _post_type}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    params = update_params_based_on_employee_role(%{}, logged_in_user.employee_role_id, logged_in_user.user_id)

    with {:ok, assisted_properties} <- AssistedProperty.list_assisted_property_by(params, [:assisted_by]),
         overview <-
           assisted_properties
           |> Enum.map(fn p -> %{assisted_by_id: p.assisted_by_id, assisted_by: p.assisted_by, status: p.status} end)
           |> Enum.group_by(fn p -> p.assisted_by_id end)
           |> Enum.map(fn {_k, v} ->
             Map.merge(hd(v).assisted_by |> Map.from_struct() |> Map.take([:id, :name, :uuid]), Enum.frequencies_by(v, fn p -> p.status end))
           end) do
      conn
      |> put_status(:ok)
      |> json(%{data: overview})
    end
  end

  def overview(conn, _params), do: conn |> put_status(:bad_request) |> json(%{message: "Invalid Params"})

  def upload_document(conn, params = %{"assisted_property_post_agreement_uuid" => _assisted_property_post_agreement_uuid}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, data} <- AssistedProperty.upload_document(params, logged_in_user.user_id) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  @spec remove_document(Plug.Conn.t(), map) :: Plug.Conn.t()
  def remove_document(conn, params = %{"assisted_property_post_agreement_uuid" => _assisted_property_post_agreement_uuid}) do
    with {:ok, data} <- AssistedProperty.remove_document(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def get_document(conn, _params = %{"assisted_property_post_agreement_uuid" => assisted_property_post_agreement_uuid}) do
    with {:ok, data} <- AssistedProperty.get_document(assisted_property_post_agreement_uuid) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def fetch_agreement(
        conn,
        _params = %{
          "assisted_property_post_agreement_uuid" => assisted_property_post_agreement_uuid,
          "owner_aadhar_number" => owner_aadhar_number,
          "owner_pan_number" => owner_pan_number,
          "owner_current_address" => owner_current_address,
          "owner_email_id" => owner_email_id,
          "property_address" => property_address
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, data} <-
           AssistedProperty.fetch_agreement(
             assisted_property_post_agreement_uuid,
             owner_aadhar_number,
             owner_pan_number,
             owner_current_address,
             owner_email_id,
             property_address,
             logged_in_user.name,
             logged_in_user.phone_number
           ) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def validate_owner_agreement(
        conn,
        _params = %{
          "assisted_property_post_agreement_uuid" => assisted_property_post_agreement_uuid
        }
      ) do
    with {:ok, invalidation_messages} <-
           AssistedProperty.validate_owner_agreement(assisted_property_post_agreement_uuid) do
      conn
      |> put_status(:ok)
      |> json(%{is_valid: length(invalidation_messages) == 0, invalidation_messages: invalidation_messages})
    end
  end

  defp update_params_based_on_employee_role(params, employee_role_id, user_id) do
    cond do
      # This is for AM manager
      employee_role_id == EmployeeRole.assisted_admin()[:id] -> Map.put(params, "assigned_by_id", user_id)
      # This is for AM
      employee_role_id == EmployeeRole.assisted_manager()[:id] -> Map.put(params, "assisted_by_id", user_id)
      # For Super and Admin
      employee_role_id == EmployeeRole.admin()[:id] or employee_role_id == EmployeeRole.super()[:id] -> params
    end
  end
end
