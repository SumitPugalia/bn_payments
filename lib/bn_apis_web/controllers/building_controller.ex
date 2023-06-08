defmodule BnApisWeb.BuildingController do
  use BnApisWeb, :controller

  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Buildings
  alias BnApis.Buildings.Building
  alias BnApis.Helpers.{Connection, ApplicationHelper}
  alias BnApis.Places.Polygon
  alias BnApisWeb.BuildingView
  alias BnApisWeb.Helpers.BuildingHelper
  alias BnApis.Posts.ConfigurationType
  alias BnApis.Buildings.BuildingEnums
  alias BnApis.Helpers.Utils
  alias BnApis.Helpers.Time

  def create_building(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    if Enum.member?(
         [
           EmployeeRole.admin().id,
           EmployeeRole.super().id,
           EmployeeRole.owner_supply_operations().id,
           EmployeeRole.owner_supply_admin().id,
           EmployeeRole.commercial_data_collector().id,
           EmployeeRole.commercial_qc().id,
           EmployeeRole.commercial_ops_admin().id,
           EmployeeRole.commercial_admin().id,
           EmployeeRole.commercial_agent().id
         ],
         logged_in_user.employee_role_id
       ) do
      params = params |> create_building_params()

      {status, message_map} =
        case Buildings.create_building(params) do
          {:ok, building} ->
            {:ok, %{building_uuid: building.uuid, id: building.id}}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:unprocessable_entity, %{errors: inspect(changeset.errors)}}
        end

      conn
      |> put_status(status)
      |> json(message_map)
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{message: "Sorry, You are not authorized to create building!"})
    end
  end

  def fetch_building(conn, %{"uuid" => building_uuid}) do
    case Buildings.get_building_by_uuid(building_uuid) do
      nil ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: "Building does not exist in our system!!"})

      building ->
        conn
        |> put_status(:ok)
        |> render(BuildingView, "show.json", %{building: building})
    end
  end

  def update_building(conn, params = %{"uuid" => building_uuid}) do
    case Repo.get_by(Building, uuid: building_uuid) do
      nil ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: "Building does not exist in our system!!"})

      building ->
        params = params |> create_building_params()

        case Buildings.update_building(building, update_building_params(params)) do
          {:ok, building} ->
            conn
            |> put_status(:ok)
            |> render(BuildingView, "show.json", %{building: building})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{message: inspect(changeset.errors)})
        end
    end
  end

  @doc """
    Requires Session
    To be used for user autocomplete from buildings
  """

  def search_buildings(conn, %{"q" => search_text}) do
    search_buildings(conn, search_text)
  end

  def search_buildings(conn, %{"q" => search_text, "exclude_building_uuids" => exclude_building_uuids}) do
    search_buildings(conn, search_text, exclude_building_uuids)
  end

  def search_buildings(conn, %{
        "q" => search_text,
        "exclude_building_uuids" => exclude_building_uuids,
        "type_id" => type_id
      }) do
    search_buildings(conn, search_text, exclude_building_uuids, type_id)
  end

  def search_buildings(conn, search_text, exclude_building_uuids \\ "", type_id \\ 1) do
    logged_in_user = Connection.get_logged_in_user(conn)
    search_text = search_text |> String.downcase()
    exclude_building_uuids = if exclude_building_uuids == "", do: [], else: exclude_building_uuids |> String.split(",")
    type_id = if not is_nil(type_id) and type_id |> is_binary(), do: String.to_integer(type_id), else: type_id || 1

    suggestions =
      Buildings.get_search_suggestions(
        search_text,
        exclude_building_uuids,
        logged_in_user.operating_city || ApplicationHelper.get_pune_city_id(),
        type_id
      )

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def admin_open_search_buildings(conn, params) do
    search_text = params["q"]
    type_id = Map.get(params, "type_id", 1)
    type_id = if is_binary(type_id), do: String.to_integer(type_id), else: type_id
    search_text = if is_binary(search_text), do: search_text |> String.downcase(), else: search_text

    suggestions =
      Buildings.get_admin_search_suggestions(search_text, [], params["city_id"], params["polygon_id"], type_id)
      |> fetch_data_for_open_search()

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def admin_search_buildings(conn, params) do
    search_text = params["q"]
    type_id = Map.get(params, "type_id", 1)
    type_id = if is_binary(type_id), do: String.to_integer(type_id), else: type_id
    search_text = if is_binary(search_text), do: search_text |> String.downcase(), else: search_text

    suggestions = Buildings.get_admin_search_suggestions(search_text, [], params["city_id"], params["polygon_id"], type_id)

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def suggestions(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    {filters, geom} = params |> BuildingHelper.process_suggestions_params()

    suggestions =
      Buildings.fetch_matching_buildings(
        params["post_type"],
        filters,
        geom,
        logged_in_user.operating_city || ApplicationHelper.get_pune_city_id(),
        params["building_type_ids"] || [1]
      )

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def landmark_suggestions(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    operating_city = logged_in_user.operating_city || ApplicationHelper.get_pune_city_id()
    {filters, geom} = params |> BuildingHelper.process_suggestions_params()
    type_id = Map.get(params, "type_id", 1)
    type_id = if is_binary(type_id), do: String.to_integer(type_id), else: type_id

    suggestions =
      Task.async(fn ->
        Buildings.fetch_matching_buildings(
          params["post_type"],
          filters,
          geom,
          operating_city,
          params["building_type_ids"] || [1]
        )
      end)

    nearby_suggestions =
      Task.async(fn ->
        Buildings.fetch_nearby_buildings(geom, operating_city, type_id, filters["exclude_building_ids"])
      end)

    results =
      (Task.await(suggestions) ++ Task.await(nearby_suggestions))
      |> Buildings.limit_landmark_building_suggestions()

    conn
    |> put_status(:ok)
    |> json(%{suggestions: results})
  end

  def admin_list_building(conn, params) do
    with {:ok, response} <- Buildings.admin_list_buildings(params) do
      conn
      |> put_status(:ok)
      |> json(%{response: response})
    end
  end

  def upload_document(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    case Buildings.upload_document(params, logged_in_user.user_id) do
      {:ok, data} ->
        conn
        |> put_status(:ok)
        |> json(data)

      {:error, data} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(data)
    end
  end

  def meta_data(conn, _params) do
    with {:ok, data} <- Buildings.meta_data() do
      conn
      |> put_status(:ok)
      |> json(%{meta_data: data})
    end
  end

  def remove_document(conn, params) do
    with {:ok, data} <- Buildings.remove_document(params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def upload_building_txn_csv(
        conn,
        _params = %{
          "building_uuid" => building_uuid,
          "building_csv" => %Plug.Upload{
            content_type: _content_type,
            filename: filename,
            path: filepath
          }
        }
      ) do
    {filepath_to_save, working_directory} = copy_to_tmp_dir(filename, filepath)

    with building when not is_nil(building) <- Buildings.get_building_by_uuid(building_uuid) |> IO.inspect(label: "Building"),
         :ok <- Buildings.save_building_txn(building.building_id, filepath_to_save),
         :ok <- File.rm_rf(working_directory) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Saved Building Transaction"})
    else
      _ ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Saved Building Transaction"})
    end
  rescue
    err in RuntimeError ->
      %RuntimeError{message: msg} = err

      conn
      |> put_status(:bad_request)
      |> json(%{message: msg})
  end

  def upload_building_txn_csv(
        conn,
        _params
      ) do
    conn
    |> put_status(:bad_request)
    |> json(%{message: "missing building_id / building_csv"})
  end

  def download_building_txn_csv(conn, _params) do
    columns = [
      :wing,
      :area,
      :price,
      :unit_number,
      :transaction_type,
      :transaction_date,
      :configuration_type
    ]

    response =
      [columns]
      |> CSV.encode()
      |> Enum.to_list()
      |> to_string()

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"building_transaction.csv\"")
    |> send_resp(200, response)
  end

  def building_txn(conn, %{"uuid" => building_uuid}) do
    with building when not is_nil(building) <- Buildings.get_building_by_uuid(building_uuid),
         transactions <- Buildings.fetch_building_transactions(building.building_id) do
      data =
        if length(transactions) > 0 do
          latest_transaction = hd(transactions)

          {total_price, total_area} =
            Enum.reduce(transactions, {0, 0}, fn transaction, {price, area} ->
              {price + transaction.price, area + transaction.area}
            end)

          avg_price_per_sqft = div(total_price, total_area)

          grouped_transactions =
            transactions
            |> Enum.sort_by(& &1.configuration_type_id, :asc)
            |> Enum.group_by(& &1.configuration_type_id)
            |> Enum.reduce([], fn {_k, v}, acc ->
              [v | acc]
            end)

          %{
            building_name: building.name,
            total_wings: 0,
            address: building.display_address,
            avg_price_per_sqft: avg_price_per_sqft,
            last_txn_date: Time.get_formatted_datetime(latest_transaction.transaction_date, "%d %b %Y"),
            last_txn_value: latest_transaction.price,
            last_price_per_sqft: div(latest_transaction.price, latest_transaction.area),
            summary: Enum.map(grouped_transactions, &format_summary/1),
            transactions:
              transactions
              |> Enum.reverse()
              |> Enum.reduce({[], nil}, fn transaction, {res, last_price_per_sqft} ->
                {[format_transaction(transaction, last_price_per_sqft) | res], div(transaction.price, transaction.area)}
              end)
              |> elem(0)
          }
        else
          %{
            building_name: building.name,
            total_wings: 0,
            address: building.display_address,
            avg_price_per_sqft: nil,
            last_txn_date: nil,
            last_txn_value: nil,
            summary: [],
            transactions: []
          }
        end

      conn
      |> put_status(:ok)
      |> json(data)
    else
      nil -> {:error, "invalid building uuid"}
    end
  end

  defp format_transaction(transaction, last_price_per_sqft) do
    %{name: name} = ConfigurationType.get_by_id(transaction.configuration_type_id)

    %{
      date: Time.get_formatted_datetime(transaction.transaction_date, "%d %b %Y"),
      configuration_type: name,
      unit_number: transaction.unit_number,
      wing: transaction.wing,
      area: transaction.area,
      transaction_type: transaction.transaction_type,
      price: transaction.price,
      deviation: if(is_nil(last_price_per_sqft), do: nil, else: div((div(transaction.price, transaction.area) - last_price_per_sqft) * 100, last_price_per_sqft))
    }
  end

  defp format_summary(transactions) do
    configuration_type_id = hd(transactions).configuration_type_id
    %{name: name} = ConfigurationType.get_by_id(configuration_type_id)

    summary =
      Enum.reduce(transactions, %{max_area: 0, min_area: 999_999, total_area: 0, total_value: 0, resale_price_12m: [], developer_deal_price_12m: []}, fn transaction, acc ->
        %{
          max_area: if(transaction.area > acc.max_area, do: transaction.area, else: acc.max_area),
          min_area: if(transaction.area < acc.min_area, do: transaction.area, else: acc.min_area),
          total_area: transaction.area + acc.total_area,
          total_value: transaction.price + acc.total_value,
          resale_price_12m:
            if(transaction.transaction_type == :resale and Date.diff(NaiveDateTime.utc_now(), transaction.transaction_date) < 365,
              do: [transaction.price | acc.resale_price_12m],
              else: acc.resale_price_12m
            ),
          developer_deal_price_12m:
            if(transaction.transaction_type == :developer and Date.diff(NaiveDateTime.utc_now(), transaction.transaction_date) < 365,
              do: [transaction.price | acc.developer_deal_price_12m],
              else: acc.developer_deal_price_12m
            )
        }
      end)

    %{
      configuration: name,
      area: "#{summary.min_area} - #{summary.max_area}",
      avg_per_sqft_rate: div(summary.total_value, summary.total_area),
      resale_avg_price_12m: if(length(summary.resale_price_12m) > 0, do: div(Enum.sum(summary.resale_price_12m), length(summary.resale_price_12m)), else: nil),
      developer_deal_avg_price_12m:
        if(length(summary.developer_deal_price_12m) > 0, do: div(Enum.sum(summary.developer_deal_price_12m), length(summary.developer_deal_price_12m)), else: nil)
    }
  end

  ## Private functions
  defp create_building_params(params) do
    type_id = Map.get(params, "type_id", 1)
    type_id = if is_binary(type_id), do: String.to_integer(type_id), else: type_id

    params =
      params
      |> Map.merge(%{
        "type" => BuildingEnums.get_building_type_from_id(type_id)
      })

    params =
      params
      |> Map.merge(%{
        "location" => Utils.create_geopoint(params)
      })

    params =
      if params["polygon_uuid"] |> is_nil() do
        params |> put_in(["polygon_id"], Polygon.fetch_or_create_polygon("Default").id)
      else
        params |> put_in(["polygon_id"], Polygon.fetch_from_uuid(params["polygon_uuid"]).id)
      end

    params =
      if not is_nil(params["grade_id"]) do
        params |> put_in(["grade"], BuildingEnums.get_building_grade_from_id(params["grade_id"]))
      else
        params
      end

    params
  end

  defp update_building_params(params) do
    params
    |> Map.merge(%{
      "location" => Utils.create_geopoint(params)
    })
  end

  defp fetch_data_for_open_search(buildings) do
    Enum.map(buildings, fn building ->
      %{
        id: building[:id],
        name: building[:name],
        address: building[:display_address]
      }
    end)
  end

  defp copy_to_tmp_dir(filename, filepath) do
    random_directory_name = SecureRandom.urlsafe_base64(64)
    working_directory = "tmp/file_worker/#{random_directory_name}"
    File.mkdir_p!(working_directory)
    filepath_to_save = "#{working_directory}/#{filename}"
    File.cp(filepath, filepath_to_save)
    {filepath_to_save, working_directory}
  end
end
