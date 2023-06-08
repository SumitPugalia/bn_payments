defmodule BnApis.Contacts.UserContact do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Helpers.FormHelper

  schema "users_contacts" do
    field :contact_id, :integer
    field :label, :string
    field :name, :string
    field :phone_number, :string
    field :user_id, :id

    timestamps()
  end

  @required [:contact_id, :name, :phone_number, :label, :user_id]
  @fields @required

  @doc false
  def changeset(user_contact, attrs) do
    user_contact
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> foreign_key_constraint(:user_id)
    |> FormHelper.validate_phone_number(:phone_number)
  end
end
