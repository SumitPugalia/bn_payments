defmodule BnApisWeb.UserContactView do
  use BnApisWeb, :view
  alias BnApisWeb.UserContactView

  def render("index.json", %{users_contacts: users_contacts}) do
    %{data: render_many(users_contacts, UserContactView, "user_contact.json")}
  end

  def render("show.json", %{user_contact: user_contact}) do
    %{data: render_one(user_contact, UserContactView, "user_contact.json")}
  end

  def render("user_contact.json", %{user_contact: user_contact}) do
    %{
      id: user_contact.id,
      contact_id: user_contact.contact_id,
      name: user_contact.name,
      phone_number: user_contact.phone_number,
      label: user_contact.label
    }
  end
end
