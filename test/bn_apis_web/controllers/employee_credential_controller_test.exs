defmodule BnApisWeb.EmployeeCredentialControllerTest do
  use BnApisWeb.ConnCase, async: true

  import Mox

  alias BnApis.Accounts
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Accounts.ProfileType
  alias BnApis.Helpers.Token
  alias BnApis.Places.Polygon
  alias BnApis.Accounts.Credential
  alias BnApis.Accounts.WhitelistedBrokerInfo
  alias BnApis.Accounts.WhitelistedNumber
  alias BnApis.Repo

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup :verify_on_exit!

  describe "POST /whitelist_broker" do
    setup map do
      {token, credential} = get_employee_token()
      Map.merge(map, %{token: token, emp_cred: credential})
    end

    test "success when country_code is not given", %{conn: conn, token: token, emp_cred: employee} do
      # given
      payload = whitelist_broker_payload(employee.uuid)

      # when
      expect_sms(employee.country_code <> employee.phone_number, payload.broker_name)

      # then
      result =
        conn
        |> assign_admin_token(token)
        |> post(Routes.employee_credential_path(conn, :whitelist_broker), payload)
        |> json_response(200)

      assert result == %{"message" => "Successfully whitelisted", "unique_code" => '-'}
      assert_broker_created(payload)
    end

    test "success when country_code for UAE given", %{conn: conn, token: token, emp_cred: employee} do
      # given
      payload =
        Map.merge(
          whitelist_broker_payload(employee.uuid),
          %{country_code: "+971", phone_number: "556123456"}
        )

      # when
      expect_sms(employee.country_code <> employee.phone_number, payload.broker_name)

      # then
      result =
        conn
        |> assign_admin_token(token)
        |> post(Routes.employee_credential_path(conn, :whitelist_broker), payload)
        |> json_response(200)

      assert result == %{"message" => "Successfully whitelisted", "unique_code" => '-'}
      assert_broker_created(payload)
    end

    test "error when invalid phone number", %{conn: conn, token: token, emp_cred: employee} do
      # given
      payload =
        Map.merge(
          whitelist_broker_payload(employee.uuid),
          %{phone_number: "00000"}
        )

      # when

      # then
      result =
        conn
        |> assign_admin_token(token)
        |> post(Routes.employee_credential_path(conn, :whitelist_broker), payload)
        |> json_response(422)

      assert result == %{"message" => "Something is not right with your phone_number, check and try again"}
    end

    test "error when invalid country_code", %{conn: conn, token: token, emp_cred: employee} do
      # given
      payload =
        Map.merge(
          whitelist_broker_payload(employee.uuid),
          %{country_code: "+1", phone_number: "556123456"}
        )

      # when

      # then
      result =
        conn
        |> assign_admin_token(token)
        |> post(Routes.employee_credential_path(conn, :whitelist_broker), payload)
        |> json_response(422)

      assert result == %{"message" => "Invalid country calling code"}
    end
  end

  defp whitelist_broker_payload(uuid),
    do: %{
      assign_to: uuid,
      broker_name: Faker.Person.first_name(),
      firm_address: Faker.Address.street_address(true),
      organization_name: Faker.Company.name(),
      phone_number: "9999999997",
      place_id: nil,
      polygon_uuid: get_dummy_polygon().uuid,
      country_code: nil
    }

  defp assign_admin_token(conn, token),
    do:
      conn
      |> Plug.Conn.put_req_header("session-token", token)
      |> Plug.Conn.assign(:user, %{"profile" => %{"employee_role_id" => EmployeeRole.admin().id}})

  defp get_employee_token() do
    user_map = %{user_id: 1, user_type: "broker"}

    {:ok, credential} =
      Accounts.create_employee_credential(
        %{
          name: Faker.Person.first_name(),
          phone_number: "9999999998",
          country_code: "+91",
          employee_code: "123",
          email: Faker.Person.first_name() <> "@broker.com",
          city_id: 1,
          active: true,
          employee_role_id: EmployeeRole.admin().id,
          reporting_manager_id: 1,
          access_city_ids: [1],
          vertical_id: 1
        },
        user_map
      )

    {:ok, token} = Token.initialize_employee_token(credential)
    {token, credential}
  end

  defp get_dummy_polygon(), do: Repo.get_by(Polygon, name: "test_polygon")

  defp expect_sms(phone_number, name) do
    expect(SmsServiceMock, :send_sms, fn to, message, _, _ ->
      assert to == phone_number
      assert message =~ name
      {:ok, %{}}
    end)
  end

  defp assert_broker_created(_payload = %{phone_number: phone_number, country_code: country_code}) do
    country_code = country_code || "+91"
    assert Credential.fetch_credential(phone_number, country_code)
    assert WhitelistedBrokerInfo.fetch_whitelisted_number(phone_number, country_code)
    assert WhitelistedNumber.fetch_whitelisted_number(phone_number, country_code)
  end
end
