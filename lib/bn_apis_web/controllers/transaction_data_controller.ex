defmodule BnApisWeb.TransactionDataController do
  use BnApisWeb, :controller

  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Transactions
  alias BnApis.Transactions.{TransactionData, Transaction}
  alias BnApis.Helpers.{Connection, ExternalApiHelper}

  action_fallback BnApisWeb.FallbackController

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.admin().id,
           EmployeeRole.super().id,
           EmployeeRole.transaction_data_cleaner().id
         ]
       ]
       when action in [
              :fetch_unprocessed_transaction_data,
              :save_transaction,
              :mark_invalid
            ]

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.admin().id,
           EmployeeRole.super().id,
           EmployeeRole.quality_controller().id
         ]
       ]
       when action in [
              :similar_buildings,
              :merge_incorrect_buildings,
              :fetch_random_processed_transaction,
              :mark_processed_data
            ]

  defp access_check(conn, options) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    if logged_in_user.employee_role_id in options[:allowed_roles] do
      conn
    else
      conn
      |> send_resp(401, "Sorry, You are not authorized to take this action!")
      |> halt()
    end
  end

  def index(conn, _params) do
    transactions_data = Transactions.list_transactions_data()
    render(conn, "index.json", transactions_data: transactions_data)
  end

  def create(conn, %{"transaction_data" => transaction_data_params}) do
    with {:ok, %TransactionData{} = transaction_data} <- Transactions.create_transaction_data(transaction_data_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.transaction_data_path(conn, :show, transaction_data))
      |> render("show.json", transaction_data: transaction_data)
    end
  end

  # def show(conn, %{"id" => id}) do
  #   transaction_data = Transactions.get_transaction_data!(id)
  #   render(conn, "show.json", transaction_data: transaction_data)
  # end

  # def update(conn, %{"id" => id, "transaction_data" => transaction_data_params}) do
  #   transaction_data = Transactions.get_transaction_data!(id)

  #   with {:ok, %TransactionData{} = transaction_data} <- Transactions.update_transaction_data(transaction_data, transaction_data_params) do
  #     render(conn, "show.json", transaction_data: transaction_data)
  #   end
  # end

  # fetches last data from sro_id
  def fetch_data_from_sro(conn, %{"sro_id" => sro_id}) do
    transaction_data = Transactions.get_transaction_data_from_sro(sro_id)
    render(conn, "show.json", transaction_data: transaction_data)
  end

  def check_if_exists(conn, %{"year" => year, "sro_id" => sro_id, "document_id" => document_id}) do
    exist = Transactions.check_if_exists(year, sro_id, document_id)

    conn
    |> put_status(:ok)
    |> json(exist)
  end

  def fetch_unprocessed_transaction_data(conn, _params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, %TransactionData{} = transaction_data} <-
           Transactions.fetch_unprocessed_transaction_data(logged_in_user[:user_id], logged_in_user[:skip_allowed]) do
      render(conn, "unprocessed_transaction_data.json", transaction_data: transaction_data)
    end
  end

  @doc """
  building_id case
  """
  def save_transaction(
        conn,
        params = %{
          "flat_no" => _flat_no,
          "floor_no" => _floor_no,
          "transaction_type" => _transaction_type,
          "transaction_data_id" => _transaction_data_id,
          "registration_date" => _registration_date,
          "building_id" => _building_id,
          "area" => _area
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    params = params |> Map.merge(%{user_id: logged_in_user[:user_id]})

    with {:ok, %Transaction{} = _transaction} <- Transactions.save_transaction(params) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Saved Successfully!"})
    end
  end

  def save_transaction(
        conn,
        params = %{
          "flat_no" => _flat_no,
          "floor_no" => _floor_no,
          "transaction_type" => "rent",
          "transaction_data_id" => _transaction_data_id,
          "building_name" => _building_name,
          "registration_date" => _registration_date,
          "place_id" => _place_id,
          # "address/locality/building_id" => address/locality, # (Any one of these are required)
          "latitude" => _latitude,
          "longitude" => _longitude,
          "area" => _area,
          "rent" => _rent,
          "tenure_for_rent" => _tenure_for_rent
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    params = params |> Map.merge(%{user_id: logged_in_user[:user_id]})

    with {:ok, %Transaction{} = _transaction} <- Transactions.save_transaction(params) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Saved Successfully!"})
    end
  end

  def save_transaction(
        conn,
        params = %{
          "flat_no" => _flat_no,
          "floor_no" => _floor_no,
          "transaction_type" => "resale",
          "transaction_data_id" => _transaction_data_id,
          "building_name" => _building_name,
          "registration_date" => _registration_date,
          "place_id" => _place_id,
          # "address/locality/building_id" => address/locality, # (Any one of these are required)
          "latitude" => _latitude,
          "longitude" => _longitude,
          "area" => _area,
          "price" => _price
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    params = params |> Map.merge(%{user_id: logged_in_user[:user_id]})

    with {:ok, %Transaction{} = _transaction} <- Transactions.save_transaction(params) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Saved Successfully!"})
    end
  end

  def mark_invalid(conn, %{"transaction_id" => transaction_id, "invalid_reason" => invalid_reason}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, %TransactionData{} = _transaction} <-
           Transactions.mark_invalid(transaction_id, logged_in_user[:user_id], invalid_reason) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully marked as inactive!"})
    end
  end

  # def delete(conn, %{"id" => id}) do
  #   transaction_data = Transactions.get_transaction_data!(id)
  #   with {:ok, %TransactionData{}} <- Transactions.delete_transaction_data(transaction_data) do
  #     send_resp(conn, :no_content, "")
  #   end
  # end

  def list_districts(conn, _params) do
    districts_data = Transactions.list_transactions_districts()
    render(conn, "districts.json", districts_data: districts_data)
  end

  def search_buildings(conn, %{"q" => search_text}) do
    search_text = search_text |> String.downcase()

    suggestions = Task.async(fn -> building_suggestions(search_text) end)
    google_suggestions = Task.async(fn -> google_building_suggestions(search_text) end)
    suggestions = remove_duplicate_suggestions(Task.await(suggestions, 10_000), Task.await(google_suggestions, 10_000))

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def building_suggestions(search_text) do
    Transactions.get_search_suggestions(search_text)
    |> add_google_building_flag(false)
  end

  def google_building_suggestions(search_text) do
    ExternalApiHelper.predict_place(search_text)
    |> add_google_building_flag(true)
  end

  def add_google_building_flag(suggestions, google_building) do
    suggestions
    |> Enum.map(fn suggestion ->
      put_in(suggestion, [:google_building], google_building)
    end)
  end

  def remove_duplicate_suggestions(db_suggestions, google_suggestions) do
    db_building_place_ids = db_suggestions |> Enum.map(& &1[:place_id])
    google_suggestions = google_suggestions |> Enum.reject(&(&1["place_id"] in db_building_place_ids))
    db_suggestions ++ google_suggestions
  end

  def probable_duplicate_buildings_list(conn, _params) do
    duplicate_buildings = Transactions.list_duplicate_buildings()
    render(conn, "index.json", duplicate_buildings: duplicate_buildings)
  end

  def search_all_similar_buildings(conn, _params = %{"q" => search_text}) do
    similar_buildings = Transactions.search_similar_buildings(search_text)

    conn
    |> put_status(:ok)
    |> json(%{similar_buildings: similar_buildings})
  end

  def search_db_buildings(conn, _params = %{"q" => search_text}) do
    buildings = Transactions.search_db_buildings(search_text)

    conn
    |> put_status(:ok)
    |> json(%{buildings: buildings})
  end

  def merge_incorrect_buildings(conn, %{
        "incorrect_building_ids" => incorrect_building_ids,
        "correct_building_id" => correct_building_id
      }) do
    incorrect_building_ids = incorrect_building_ids -- [correct_building_id]
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    Transactions.merge_incorrect_buildings(logged_in_user[:user_id], incorrect_building_ids, correct_building_id)

    conn
    |> put_status(:ok)
    |> json(%{message: "Successfully merged buildings!"})
  end

  def hide_temp_building(conn, %{"name" => name}) do
    Transactions.hide_temp_buildings(name)

    conn
    |> put_status(:ok)
    |> json(%{message: "Successfully hided buildings!"})
  end

  def fetch_random_processed_transaction(conn, _params) do
    with {:ok, %Transaction{} = transaction} <- Transactions.fetch_random_processed_transaction() do
      render(conn, "processed_transaction_data.json", transaction: transaction)
    end
  end

  def mark_processed_data(conn, %{"transaction_id" => transaction_id, "correct" => "true"}) do
    with {:ok, %Transaction{} = _transaction} <- Transactions.mark_processed_data(transaction_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully marked correct!"})
    end
  end

  def mark_processed_data(conn, %{
        "transaction_id" => transaction_id,
        "correct" => "false",
        "wrong_reason" => wrong_reason
      }) do
    with {:ok, %Transaction{} = _transaction} <- Transactions.mark_processed_data(transaction_id, wrong_reason) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully marked wrong!"})
    end
  end
end
