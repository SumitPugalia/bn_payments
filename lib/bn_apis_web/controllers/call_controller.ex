defmodule BnApisWeb.CallController do
  use BnApisWeb, :controller

  alias BnApis.Calls
  alias BnApis.Homeloan.Lead
  alias BnApis.Helpers.Connection
  alias BnApisWeb.Helpers.PhoneHelper
  alias BnApis.Repo

  def authenticate_s2c_api(conn, api_token) do
    if api_token != Application.get_env(:bn_apis, :s2c_api_token) do
      response = %{"reason" => "Unauthorized, Please check the api-token"}
      xml_response = MapToXml.from_map(response)
      conn |> send_resp(401, xml_response) |> halt()
    end
  end

  # inbound webhook api to send the number
  def get_number_to_connect(conn, params) do
    params = params.xml["request"]
    authenticate_s2c_api(conn, params["api_token"])

    response =
      case params["msg_type"] do
        "lookup" ->
          params |> create_get_number_to_connect_params() |> Calls.get_number_to_connect()

        "outbound_notify" ->
          Calls.create_response_for_outbound_notify(params)
      end

    xml_response = MapToXml.from_map(response)
    send_resp(conn, 200, xml_response)
  end

  # cdr to save call details
  def save_call_details(conn, params) do
    params = params.xml["request"]
    authenticate_s2c_api(conn, params["api_token"])

    with {:ok, _data} <- Calls.save_call_details(params) do
      response = %{
        "msg_type" => "cdr.ack",
        "reason" => "Success",
        "result" => 200
      }

      response = %{"reply" => response}
      xml_response = MapToXml.from_map(response)
      send_resp(conn, 200, xml_response)
    end
  end

  # outbound api call
  def connect_call(
        conn,
        params = %{
          "lead_id" => _lead_id,
          "call_with" => _call_with
        }
      ) do
    s2c_params = create_connect_call_params(conn, params)

    with {:ok, data} <- Calls.connect_call_to_client(s2c_params) do
      conn
      |> put_status(:ok)
      |> json(%{data: data})
    end
  end

  def connect_call(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{message: "Invalid Params"})
  end

  defp create_get_number_to_connect_params(params) do
    %{
      "client_number" => params["cli"],
      "agent_type" => Calls.get_agent_type_by_phone_number(params["access_number"]),
      "tran_id" => params["tran_id"]
    }
  end

  defp create_connect_call_params(
         conn,
         params = %{
           "lead_id" => lead_id,
           "call_with" => call_with
         }
       ) do
    params = Map.put(params, "tran_id", Ecto.UUID.generate())

    case call_with do
      # call from admin panel to broker
      "broker" ->
        user = Connection.get_employee_logged_in_user(conn)
        params = Map.put(params, "agent_number", PhoneHelper.append_country_code(user.phone_number, "91"))
        broker_cred = Lead.get_broker_using_lead_id(lead_id)
        broker_number = PhoneHelper.append_country_code(broker_cred.phone_number, "91")
        params = Map.put(params, "customer_number", broker_number)
        Map.put(params, "call_type", "outbound")

      # call from admin panel to lead
      "hl_lead" ->
        user = Connection.get_employee_logged_in_user(conn)
        params = Map.put(params, "agent_number", PhoneHelper.append_country_code(user.phone_number, "91"))
        lead = Lead.get_homeloan_lead(lead_id)
        lead_number = PhoneHelper.append_country_code(lead.phone_number, "91")
        params = Map.put(params, "customer_number", lead_number)
        Map.put(params, "call_type", "outbound")

      # call from broker app to agent
      "hl_agent" ->
        user = Connection.get_logged_in_user(conn)
        params = Map.put(params, "agent_number", PhoneHelper.append_country_code(user.phone_number, "91"))
        lead = Lead.get_homeloan_lead(lead_id)
        lead = Repo.preload(lead, :employee_credentials)
        employee_number = lead.employee_credentials.phone_number
        employee_number = PhoneHelper.append_country_code(employee_number, "91")
        params = Map.put(params, "customer_number", employee_number)
        Map.put(params, "call_type", "inbound")
    end
  end
end
