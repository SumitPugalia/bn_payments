defmodule BnApisWeb.UserContactController do
  use BnApisWeb, :controller

  alias BnApis.Contacts

  action_fallback BnApisWeb.FallbackController

  def index(conn, _params) do
    users_contacts = Contacts.list_users_contacts()
    render(conn, "index.json", users_contacts: users_contacts)
  end

  def create(conn, %{"user_contact" => user_contact_params}) do
    user_id = conn.assigns[:user]["user_id"]

    with {_inserted_count, nil} <- Contacts.create_user_contacts(user_id, user_contact_params) do
      send_resp(conn, :ok, "Successfully created!")
    end
  end

  def show(conn, %{"id" => id}) do
    user_contact = Contacts.get_user_contact!(id)

    render(conn, "show.json", user_contact: user_contact)
  end

  def update(conn, %{"id" => _id, "user_contact" => user_contact_params}) do
    user_id = conn.assigns[:user]["user_id"]

    with {_inserted_count, nil} <- Contacts.update_user_contacts(user_id, user_contact_params) do
      send_resp(conn, :ok, "Successfully updated!")
    end
  end

  def delete(conn, %{"id" => local_contact_id}) do
    user_id = conn.assigns[:user]["user_id"]

    with {_deleted_count, nil} <- Contacts.delete_user_contacts(user_id, local_contact_id) do
      send_resp(conn, :no_content, "")
    end
  end

  def bulk_sync(conn, _params = %{"contacts" => contacts}) when is_list(contacts) do
    user_id = conn.assigns[:user]["user_id"]

    with {_inserted_count, nil} <- Contacts.bulk_sync(user_id, contacts) do
      send_resp(conn, :ok, "Successfully synced!")
    end
  end

  def bulk_sync(conn, _params = %{"contacts" => contacts}) when is_binary(contacts) do
    user_id = conn.assigns[:user]["user_id"]

    with {_inserted_count, nil} <- Contacts.decode_and_bulk_sync(user_id, contacts) do
      send_resp(conn, :ok, "Successfully synced!")
    end
  end
end
