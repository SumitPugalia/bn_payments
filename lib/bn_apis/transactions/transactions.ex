defmodule BnApis.Transactions do
  @moduledoc """
  The Transactions context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Transactions.District
  alias BnApis.Helpers.Time

  @doc """
  Returns the list of transactions_districts.

  ## Examples

      iex> list_transactions_districts()
      [%District{}, ...]

  """
  def list_transactions_districts do
    Repo.all(District)
  end

  @doc """
  Gets a single district.

  Raises `Ecto.NoResultsError` if the District does not exist.

  ## Examples

      iex> get_district!(123)
      %District{}

      iex> get_district!(456)
      ** (Ecto.NoResultsError)

  """
  def get_district!(id), do: Repo.get!(District, id)

  @doc """
  Creates a district.

  ## Examples

      iex> create_district(%{field: value})
      {:ok, %District{}}

      iex> create_district(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_district(attrs \\ %{}) do
    attrs = attrs |> Map.merge(%{"name" => attrs["name"] |> String.downcase()})

    %District{}
    |> District.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a district.

  ## Examples

      iex> update_district(district, %{field: new_value})
      {:ok, %District{}}

      iex> update_district(district, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_district(%District{} = district, attrs) do
    attrs =
      case attrs["name"] do
        nil -> attrs
        name -> attrs |> Map.merge(%{"name" => name |> String.downcase()})
      end

    district
    |> District.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a District.

  ## Examples

      iex> delete_district(district)
      {:ok, %District{}}

      iex> delete_district(district)
      {:error, %Ecto.Changeset{}}

  """
  def delete_district(%District{} = district) do
    Repo.delete(district)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking district changes.

  ## Examples

      iex> change_district(district)
      %Ecto.Changeset{source: %District{}}

  """
  def change_district(%District{} = district) do
    District.changeset(district, %{})
  end

  alias BnApis.Transactions.DocType

  @doc """
  Returns the list of transactions_doctypes.

  ## Examples

      iex> list_transactions_doctypes()
      [%DocType{}, ...]

  """
  def list_transactions_doctypes do
    Repo.all(DocType)
  end

  @doc """
  Gets a single doc_type.

  Raises `Ecto.NoResultsError` if the Doc type does not exist.

  ## Examples

      iex> get_doc_type!(123)
      %DocType{}

      iex> get_doc_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_doc_type!(id), do: Repo.get!(DocType, id)

  @doc """
  Creates a doc_type.

  ## Examples

      iex> create_doc_type(%{field: value})
      {:ok, %DocType{}}

      iex> create_doc_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_doc_type(attrs \\ %{}) do
    %DocType{}
    |> DocType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a doc_type.

  ## Examples

      iex> update_doc_type(doc_type, %{field: new_value})
      {:ok, %DocType{}}

      iex> update_doc_type(doc_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_doc_type(%DocType{} = doc_type, attrs) do
    doc_type
    |> DocType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a DocType.

  ## Examples

      iex> delete_doc_type(doc_type)
      {:ok, %DocType{}}

      iex> delete_doc_type(doc_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_doc_type(%DocType{} = doc_type) do
    Repo.delete(doc_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking doc_type changes.

  ## Examples

      iex> change_doc_type(doc_type)
      %Ecto.Changeset{source: %DocType{}}

  """
  def change_doc_type(%DocType{} = doc_type) do
    DocType.changeset(doc_type, %{})
  end

  alias BnApis.Transactions.TransactionData

  @doc """
  Returns the list of transactions_data.

  ## Examples

      iex> list_transactions_data()
      [%TransactionData{}, ...]

  """
  def list_transactions_data do
    Repo.all(TransactionData)
  end

  @doc """
  Gets a single transaction_data.

  Raises `Ecto.NoResultsError` if the Transaction data does not exist.

  ## Examples

      iex> get_transaction_data!(123)
      %TransactionData{}

      iex> get_transaction_data!(456)
      ** (Ecto.NoResultsError)

  """
  def get_transaction_data!(id), do: Repo.get!(TransactionData, id)

  def get_transaction_data_from_sro(sro_id) do
    TransactionData.fetch_data_from_sro(sro_id) |> List.first()
  end

  @doc """
  Creates a transaction_data.

  ## Examples

      iex> create_transaction_data(%{field: value})
      {:ok, %TransactionData{}}

      iex> create_transaction_data(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_transaction_data(attrs \\ %{}) do
    attrs =
      if attrs["registration_date"] |> is_nil() do
        attrs
      else
        attrs |> Map.merge(%{"registration_date" => attrs["registration_date"] |> Time.epoch_to_naive()})
      end

    attrs =
      case attrs["building_uuid"] do
        nil ->
          attrs

        building_uuid ->
          {:ok, [building_id]} = BnApis.Buildings.get_ids_from_uids([building_uuid])
          attrs |> Map.merge(%{"building_id" => building_id})
      end

    %TransactionData{}
    |> TransactionData.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a transaction_data.

  ## Examples

      iex> update_transaction_data(transaction_data, %{field: new_value})
      {:ok, %TransactionData{}}

      iex> update_transaction_data(transaction_data, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_transaction_data(%TransactionData{} = transaction_data, attrs) do
    attrs =
      case attrs["registration_date"] do
        nil ->
          attrs

        registration_date ->
          attrs |> Map.merge(%{"registration_date" => registration_date |> Time.epoch_to_naive()})
      end

    attrs =
      case attrs["building_uuid"] do
        nil ->
          attrs

        building_uuid ->
          {:ok, [building_id]} = BnApis.Buildings.get_ids_from_uids([building_uuid])
          attrs |> Map.merge(%{"building_id" => building_id})
      end

    transaction_data
    |> TransactionData.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a TransactionData.

  ## Examples

      iex> delete_transaction_data(transaction_data)
      {:ok, %TransactionData{}}

      iex> delete_transaction_data(transaction_data)
      {:error, %Ecto.Changeset{}}

  """
  def delete_transaction_data(%TransactionData{} = transaction_data) do
    Repo.delete(transaction_data)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking transaction_data changes.

  ## Examples

      iex> change_transaction_data(transaction_data)
      %Ecto.Changeset{source: %TransactionData{}}

  """
  def change_transaction_data(%TransactionData{} = transaction_data) do
    TransactionData.changeset(transaction_data, %{})
  end

  alias BnApis.Transactions.Status

  @doc """
  Returns the list of transactions_statuses.

  ## Examples

      iex> list_transactions_statuses()
      [%Status{}, ...]

  """
  def list_transactions_statuses do
    Repo.all(Status)
  end

  @doc """
  Gets a single status.

  Raises `Ecto.NoResultsError` if the Status does not exist.

  ## Examples

      iex> get_status!(123)
      %Status{}

      iex> get_status!(456)
      ** (Ecto.NoResultsError)

  """
  def get_status!(id), do: Repo.get!(Status, id)

  @doc """
  Creates a status.

  ## Examples

      iex> create_status(%{field: value})
      {:ok, %Status{}}

      iex> create_status(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_status(attrs \\ %{}) do
    %Status{}
    |> Status.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a status.

  ## Examples

      iex> update_status(status, %{field: new_value})
      {:ok, %Status{}}

      iex> update_status(status, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_status(%Status{} = status, attrs) do
    status
    |> Status.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Status.

  ## Examples

      iex> delete_status(status)
      {:ok, %Status{}}

      iex> delete_status(status)
      {:error, %Ecto.Changeset{}}

  """
  def delete_status(%Status{} = status) do
    Repo.delete(status)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking status changes.

  ## Examples

      iex> change_status(status)
      %Ecto.Changeset{source: %Status{}}

  """
  def change_status(%Status{} = status) do
    Status.changeset(status, %{})
  end

  alias BnApis.Transactions.Building

  @doc """
  Returns the list of transactions_buildings.

  ## Examples

      iex> list_transactions_buildings()
      [%Building{}, ...]

  """
  def list_transactions_buildings do
    Repo.all(Building)
  end

  @doc """
  Gets a single building.

  Raises `Ecto.NoResultsError` if the Building does not exist.

  ## Examples

      iex> get_building!(123)
      %Building{}

      iex> get_building!(456)
      ** (Ecto.NoResultsError)

  """
  def get_building!(id), do: Repo.get!(Building, id)

  @doc """
  Creates a building.

  ## Examples

      iex> create_building(%{field: value})
      {:ok, %Building{}}

      iex> create_building(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_building(attrs \\ %{}) do
    %Building{}
    |> Building.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a building.

  ## Examples

      iex> update_building(building, %{field: new_value})
      {:ok, %Building{}}

      iex> update_building(building, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_building(%Building{} = building, attrs) do
    building
    |> Building.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Building.

  ## Examples

      iex> delete_building(building)
      {:ok, %Building{}}

      iex> delete_building(building)
      {:error, %Ecto.Changeset{}}

  """
  def delete_building(%Building{} = building) do
    Repo.delete(building)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking building changes.

  ## Examples

      iex> change_building(building)
      %Ecto.Changeset{source: %Building{}}

  """
  def change_building(%Building{} = building) do
    Building.changeset(building, %{})
  end

  alias BnApis.Transactions.Transaction

  @doc """
  Returns the list of transactions.

  ## Examples

      iex> list_transactions()
      [%Transaction{}, ...]

  """
  def list_transactions do
    Repo.all(Transaction)
  end

  @doc """
  Gets a single transaction.

  Raises `Ecto.NoResultsError` if the Transaction does not exist.

  ## Examples

      iex> get_transaction!(123)
      %Transaction{}

      iex> get_transaction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_transaction!(id), do: Repo.get!(Transaction, id)

  @doc """
  Creates a transaction.

  ## Examples

      iex> create_transaction(%{field: value})
      {:ok, %Transaction{}}

      iex> create_transaction(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_transaction(attrs \\ %{}) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a transaction.

  ## Examples

      iex> update_transaction(transaction, %{field: new_value})
      {:ok, %Transaction{}}

      iex> update_transaction(transaction, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Transaction.

  ## Examples

      iex> delete_transaction(transaction)
      {:ok, %Transaction{}}

      iex> delete_transaction(transaction)
      {:error, %Ecto.Changeset{}}

  """
  def delete_transaction(%Transaction{} = transaction) do
    Repo.delete(transaction)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking transaction changes.

  ## Examples

      iex> change_transaction(transaction)
      %Ecto.Changeset{source: %Transaction{}}

  """
  def change_transaction(%Transaction{} = transaction) do
    Transaction.changeset(transaction, %{})
  end

  def mark_invalid(transaction_id, logged_user_id, invalid_reason) do
    transaction_data = Repo.get!(TransactionData, transaction_id)
    transaction_data |> TransactionData.mark_as_inactive(logged_user_id, invalid_reason) |> Repo.update()
  end

  def fetch_unprocessed_transaction_data(logged_user_id, skip_allowed) do
    total_processed_documents = TransactionData.total_documents_processed_count(logged_user_id)
    today_processed_documents = TransactionData.today_documents_processed_count(logged_user_id)

    extra_data = %{
      total_processed_documents: total_processed_documents,
      today_processed_documents: today_processed_documents
    }

    in_process_transaction_data = TransactionData.fetch_transaction_data(logged_user_id, Status.in_process().id) |> Repo.one()

    case in_process_transaction_data do
      nil ->
        unprocessed_transaction_data = TransactionData.fetch_random_unprocessed_transaction(skip_allowed) |> Repo.one()

        case unprocessed_transaction_data do
          nil ->
            {:error, "No more transaction_data available."}

          unprocessed_transaction_data ->
            # Assign and Mark as in-process

            result =
              unprocessed_transaction_data
              |> TransactionData.assign_and_mark_in_process(logged_user_id)
              |> Repo.update()

            case result do
              {:ok, _td} ->
                unprocessed_transaction_data = unprocessed_transaction_data |> Map.merge(extra_data)
                {:ok, unprocessed_transaction_data}

              error ->
                error
            end
        end

      in_process_transaction_data ->
        in_process_transaction_data = in_process_transaction_data |> Map.merge(extra_data)
        {:ok, in_process_transaction_data}
    end
  end

  @doc """
  Creates building if not exist

  """
  def save_transaction(params) do
    case {params["building_id"], params["address"], params["locality"]} do
      {nil, nil, nil} ->
        {:error, "One of these 'building_id, address, or locality' is required!"}

      {nil, nil, locality} ->
        attrs = %{
          "name" => params["building_name"],
          "locality" => locality,
          "place_id" => params["place_id"],
          "location" => create_geopoint(params["latitude"], params["longitude"])
        }

        with {:ok, building} <- Building.get_or_create_locality_building(attrs) do
          create_transaction(params, building.id)
        end

      {nil, address, nil} ->
        attrs = %{
          "name" => params["building_name"],
          "address" => address,
          "place_id" => params["place_id"],
          "location" => create_geopoint(params["latitude"], params["longitude"])
        }

        with {:ok, building} <- Building.get_or_create_building(attrs) do
          create_transaction(params, building.id)
        end

      {building_id, nil, nil} ->
        create_transaction(params, building_id)

      _ ->
        {:error, "Wrong arguments passed!"}
    end
  end

  @doc """
  """
  def create_transaction(params, building_id) do
    attrs = %{
      "flat_no" => params["flat_no"],
      "floor_no" => params["floor_no"],
      "transaction_type" => params["transaction_type"],
      "transaction_data_id" => params["transaction_data_id"],
      "transaction_building_id" => building_id,
      "area" => params["area"],
      "price" => params["price"],
      "rent" => params["rent"],
      "tenure_for_rent" => params["tenure_for_rent"],
      "registration_date" => params["registration_date"] |> Time.epoch_to_naive()
    }

    case Transaction.changeset(attrs) |> Repo.insert() do
      {:ok, transaction} ->
        transaction_data_id = params["transaction_data_id"]
        transaction_data = TransactionData |> where(id: ^transaction_data_id) |> Repo.one()
        transaction_data |> TransactionData.change_status(Status.processed().id, params[:user_id]) |> Repo.update!()

        {:ok, transaction}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_geopoint(lat, long) do
    coordinates = {lat, long}
    %Geo.Point{coordinates: coordinates, srid: 4326}
  end

  def get_search_suggestions(search_text, locality_uuid) do
    Building.search_building_query(search_text, locality_uuid)
    |> Repo.all()
  end

  def get_search_suggestions(search_text) do
    Building.search_building_query(search_text)
    |> Repo.all()
  end

  def search_db_buildings(search_text) do
    Building.search_db_buildings_query(search_text)
    |> Repo.all()
  end

  def check_if_exists(year, sro_id, document_id) do
    query = TransactionData.year_sro_id_query(year, sro_id, document_id)

    case query |> Repo.one() do
      nil -> false
      _ -> true
    end
  end

  alias BnApis.Transactions.DuplicateBuildingTemp

  def list_duplicate_buildings() do
    DuplicateBuildingTemp
    |> where(hide: false)
    |> order_by([b], desc: :count, desc: :name)
    |> limit(20)
    |> Repo.all()
  end

  def search_similar_buildings(search_text) do
    Building.search_using_trgm_building_query(search_text)
    |> Repo.all()
  end

  alias BnApis.Transactions.TransactionVersion

  @doc """
  1. Creates a version of the transactions having "incorrect_building_ids" with "correct_building_id"
  2. Marks all incorrect_building_ids with delete flag true
  """
  def merge_incorrect_buildings(logged_user_id, incorrect_building_ids, correct_building_id) do
    incorrect_building_ids
    |> get_transaction_ids()
    |> Enum.each(fn transaction_id ->
      params = %{
        transaction_id: transaction_id,
        transaction_building_id: correct_building_id,
        edited_by_id: logged_user_id
      }

      TransactionVersion.changeset(params) |> Repo.insert()
    end)

    incorrect_building_ids |> Building.mark_buildings_as_deleted()
  end

  def hide_temp_buildings(building_name) do
    DuplicateBuildingTemp.hide_buildings(building_name)
  end

  def get_transaction_ids(building_ids) do
    Transaction
    |> join(:inner, [t], b in Building, on: t.transaction_building_id == b.id)
    |> join(:left, [t, b], tv in TransactionVersion, on: t.id == tv.transaction_id)
    |> join(:left, [t, b, tv], tvb in Building, on: tv.transaction_building_id == tvb.id)
    |> where(
      [t, b, tv, tvb],
      (t.transaction_building_id in ^building_ids and b.delete == false) or
        (tv.transaction_building_id in ^building_ids and tvb.delete == false)
    )
    |> select([t], t.id)
    |> distinct(true)
    |> Repo.all()
  end

  alias BnApis.Accounts.EmployeeCredential

  def fetch_random_processed_transaction() do
    random_employee_id = EmployeeCredential.fetch_random_data_cleaner_id()

    case Transaction.fetch_random_transaction_query(random_employee_id) do
      nil ->
        {:error, "No transactions found!"}

      transaction ->
        {:ok, transaction}
    end
  end

  def mark_processed_data(transaction_id) do
    Transaction.mark_correct_changeset(transaction_id) |> Repo.update()
  end

  def mark_processed_data(transaction_id, wrong_reason) do
    Transaction.mark_wrong_changeset(transaction_id, wrong_reason) |> Repo.update()
  end

  def get_transactions(params) do
    Transaction.search_transactions_query(params)
  end

  def get_transaction_html(transaction_data_id) do
    case Repo.get(TransactionData, transaction_data_id) do
      nil ->
        {:error, "Transaction Data not found!"}

      transaction_data ->
        {:ok, transaction_data}
    end
  end
end
