defmodule BnApis.Contacts do
  @moduledoc """
  The Contacts context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Contacts.UserContact

  @doc """
  Returns the list of users_contacts.

  ## Examples

      iex> list_users_contacts()
      [%UserContact{}, ...]

  """
  def list_users_contacts do
    Repo.all(UserContact)
  end

  @doc """
  Gets a single user_contact.

  Raises `Ecto.NoResultsError` if the User contact does not exist.

  ## Examples

      iex> get_user_contact!(123)
      %UserContact{}

      iex> get_user_contact!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_contact!(id), do: Repo.get!(UserContact, id)

  @doc """
  Creates a user_contact.

  ## Examples

      iex> create_user_contact(%{field: value})
      {:ok, %UserContact{}}

      iex> create_user_contact(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_contact(attrs \\ %{}) do
    %UserContact{}
    |> UserContact.changeset(attrs)
    |> Repo.insert()
  end

  def create_user_contacts(user_id, user_contact_params \\ %{}) do
    user_contact_params
    |> create_structs(user_id)
    |> Enum.reject(&is_nil/1)
    |> (&Repo.insert_all(UserContact, &1, on_conflict: :nothing)).()
  end

  @doc """
  Updates a user_contact.

  ## Examples

      iex> update_user_contact(user_contact, %{field: new_value})
      {:ok, %UserContact{}}

      iex> update_user_contact(user_contact, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_contact(%UserContact{} = user_contact, attrs) do
    user_contact
    |> UserContact.changeset(attrs)
    |> Repo.update()
  end

  def update_user_contacts(user_id, user_contact_params \\ %{}) do
    local_contact_id = user_contact_params["contact_id"] |> String.to_integer()
    UserContact |> where([u], u.user_id == ^user_id and u.contact_id == ^local_contact_id) |> Repo.delete_all()

    user_contact_params
    |> create_structs(user_id)
    |> Enum.reject(&is_nil/1)
    |> (&Repo.insert_all(UserContact, &1, on_conflict: :nothing)).()
  end

  @doc """
  Deletes a UserContact.

  ## Examples

      iex> delete_user_contact(user_contact)
      {:ok, %UserContact{}}

      iex> delete_user_contact(user_contact)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_contact(%UserContact{} = user_contact) do
    Repo.delete(user_contact)
  end

  def delete_user_contacts(user_id, local_contact_id) do
    UserContact |> where([u], u.user_id == ^user_id and u.contact_id == ^local_contact_id) |> Repo.delete_all()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_contact changes.

  ## Examples

      iex> change_user_contact(user_contact)
      %Ecto.Changeset{source: %UserContact{}}

  """
  def change_user_contact(%UserContact{} = user_contact) do
    UserContact.changeset(user_contact, %{})
  end

  @doc """
  request sample: [
    {
      "contact_id": "23",
      "name": "John Connor",
      "phone_numbers": [
        {
          "label": "mobile",
          "number": "+91 (961)-964-4833"
        },
        {
          "label": "work",
          "number": "+91 (961)-964-4811"
        }
      ]
    },
    {
      "contact_id": "32",
      "name": "Sarah Connor",
      "phone_numbers": [
        {
          "label": "mobile",
          "number": "+91 (961)-964-4813"
        }
      ]
    }
  ]
  """
  def decode_and_bulk_sync(user_id, contacts) do
    case contacts |> Poison.decode() do
      {:ok, contacts} ->
        bulk_sync(user_id, contacts)

      _ ->
        {:error, "Invalid contacts data!"}
    end
  end

  def bulk_sync(user_id, contacts) do
    # DELETE ALL PREVIOUS RECORDS
    UserContact |> where(user_id: ^user_id) |> Repo.delete_all()

    contacts
    |> Enum.reduce([], fn contact, acc ->
      structs = create_structs(contact, user_id) |> Enum.reject(&is_nil/1)
      acc ++ structs
    end)
    |> (&Repo.insert_all(UserContact, &1, on_conflict: :nothing)).()
  end

  def create_structs(contact, user_id) do
    contact["phone_numbers"]
    |> Enum.map(fn %{"label" => label, "number" => number} ->
      case ExPhoneNumber.parse(number, "IN") do
        {:ok, phone_number} ->
          if ExPhoneNumber.is_valid_number?(phone_number) do
            %{
              user_id: user_id,
              contact_id: contact["contact_id"] |> String.to_integer(),
              name: contact["name"],
              phone_number: phone_number.national_number |> to_string,
              label: label,
              inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
              updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
            }
          end

        _ ->
          nil
      end
    end)
  end

  alias BnApis.Contacts.BrokerUniverse

  @doc """
  Returns the list of brokers_universe.

  ## Examples

      iex> list_brokers_universe()
      [%BrokerUniverse{}, ...]

  """
  def list_brokers_universe do
    Repo.all(BrokerUniverse)
  end

  @doc """
  Gets a single broker_universe.

  Raises `Ecto.NoResultsError` if the Broker universe does not exist.

  ## Examples

      iex> get_broker_universe!(123)
      %BrokerUniverse{}

      iex> get_broker_universe!(456)
      ** (Ecto.NoResultsError)

  """
  def get_broker_universe!(id), do: Repo.get!(BrokerUniverse, id)

  def get_broker_from_universe_by_phone(phone, country_code) do
    {:ok, phone} = ExPhoneNumber.parse(phone, "IN")
    phone_number = phone.national_number |> Integer.to_string()
    Repo.get_by(BrokerUniverse, phone_number: phone_number, country_code: country_code)
  end

  @doc """
  Creates a broker_universe.

  ## Examples

      iex> create_broker_universe(%{field: value})
      {:ok, %BrokerUniverse{}}

      iex> create_broker_universe(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_broker_universe(attrs \\ %{}) do
    %BrokerUniverse{}
    |> BrokerUniverse.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a broker_universe.

  ## Examples

      iex> update_broker_universe(broker_universe, %{field: new_value})
      {:ok, %BrokerUniverse{}}

      iex> update_broker_universe(broker_universe, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_broker_universe(%BrokerUniverse{} = broker_universe, attrs) do
    broker_universe
    |> BrokerUniverse.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a BrokerUniverse.

  ## Examples

      iex> delete_broker_universe(broker_universe)
      {:ok, %BrokerUniverse{}}

      iex> delete_broker_universe(broker_universe)
      {:error, %Ecto.Changeset{}}

  """
  def delete_broker_universe(%BrokerUniverse{} = broker_universe) do
    Repo.delete(broker_universe)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking broker_universe changes.

  ## Examples

      iex> change_broker_universe(broker_universe)
      %Ecto.Changeset{source: %BrokerUniverse{}}

  """
  def change_broker_universe(%BrokerUniverse{} = broker_universe) do
    BrokerUniverse.changeset(broker_universe, %{})
  end
end
