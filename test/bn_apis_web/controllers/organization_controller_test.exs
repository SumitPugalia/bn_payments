defmodule BnApisWeb.OrganizationControllerTest do
  use BnApisWeb.ConnCase, async: true

  import Mox

  alias BnApis.Buildings.Building
  alias BnApis.Factory
  alias BnApis.Organizations.BrokerRole
  alias BnApis.Repo
  alias BnApis.Tests.Utils

  @token "dummy_token"
  @admin_role Integer.to_string(BrokerRole.admin().id)
  @member_role Integer.to_string(BrokerRole.chhotus().id)

  setup %{conn: conn} do
    credential = Factory.insert(:credential)
    conn = put_req_header(conn, "accept", "application/json") |> put_req_header("session-token", @token)

    {:ok, %{conn: conn, credential: credential}}
  end

  setup :verify_on_exit!

  describe "POST /api/invites" do
    test "user invites member", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)
      payload = %{"phone_number" => Utils.random_mobile_number(), "broker_name" => Faker.Person.first_name(), "broker_role_id" => @admin_role}
      Utils.expect_sms(payload["phone_number"], payload["broker_name"], :sms)

      conn
      |> post(Routes.organization_path(conn, :send_invite), payload)
      |> json_response(200)
    end

    for user_type <- [@admin_role, @member_role] do
      for is_whitelisted? <- [true, false] do
        @user_type user_type
        @is_whitelisted is_whitelisted?
        test "invited #{@user_type} joins app (verify otp and sign up) when whitelisted is #{@is_whitelisted}", %{conn: conn, credential: credential} do
          # given

          phone_number = Utils.random_mobile_number()
          employee = Factory.insert(:employee_credential)

          if @is_whitelisted, do: whitelist_params(phone_number, credential, employee)

          # when
          payload = %{"phone_number" => phone_number, "broker_name" => Faker.Person.first_name(), "broker_role_id" => @user_type, "country_code" => "+91"}
          send_invite(conn, payload, credential.uuid)

          # then
          otp = "#{Enum.random(1000..9999)}"
          Utils.mock_send_otp_redis(otp, payload["phone_number"], nil)

          result =
            conn
            |> post(Routes.v1_credential_path(conn, :send_otp), payload)
            |> json_response(200)
            |> Map.drop(["max_count_allowed", "otp_requested_count", "request_id"])

          assert %{
                   "broker_name" => payload["broker_name"],
                   "broker_role_id" => String.to_integer(@user_type),
                   "invited_by_name" => credential.broker.name,
                   "organization_id" => credential.organization.id,
                   "organization_name" => credential.organization.name,
                   "profile_pic_url" => nil,
                   "invitor_phone_number" => credential.phone_number,
                   "org_address" => credential.organization.firm_address
                 } == hd(result["invites"]) |> Map.drop(["sent_date"])

          assert result["whitelisted"] == @is_whitelisted

          validate_otp_and_signup_user(conn, payload["phone_number"], otp, credential.organization.id)

          new_user = Repo.get_by(BnApis.Accounts.Credential, phone_number: payload["phone_number"])
          assert @user_type == Integer.to_string(new_user.broker_role_id)
        end
      end
    end

    test "POST /accounts/leave", %{conn: conn, credential: credential} do
      ## given
      # create billing company for old user
      old_billing_company = Factory.insert(:billing_company, %{broker: credential.broker})

      # create successor
      user2 = Factory.insert(:credential, %{organization: credential.organization})

      ## when
      Utils.expect_token(credential.uuid)

      conn
      |> post(Routes.credential_path(conn, :leave_user), %{"successor_uuid" => user2.uuid})
      |> json_response(200)

      ## then
      # check if billing comapny was migrated to successor
      new_user = Repo.preload(Repo.reload(user2), broker: :billing_companies)
      assert hd(new_user.broker.billing_companies).id == old_billing_company.id
    end
  end

  describe "POST /accounts/:user_uuid/promote" do
    test "failure when promote self", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)

      assert %{"message" => "Sorry, cannot promote own account!"} ==
               conn
               |> post(Routes.credential_path(conn, :promote_user, credential.uuid))
               |> json_response(422)
    end

    test "failure when promote admin", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)
      user2 = Factory.insert(:credential, %{organization: credential.organization})

      assert %{"message" => "User is already an admin!"} ==
               conn
               |> post(Routes.credential_path(conn, :promote_user, user2.uuid))
               |> json_response(422)
    end

    test "success when promote member", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)
      user2 = Factory.insert(:credential, %{organization: credential.organization, broker_role_id: 2})

      assert %{"message" => "User successfully promoted!"} ==
               conn
               |> post(Routes.credential_path(conn, :promote_user, user2.uuid))
               |> json_response(200)
    end
  end

  describe "POST /accounts/:user_uuid/demote" do
    test "failure when demote self", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)

      assert %{"message" => "Sorry, cannot demote own account!"} ==
               conn
               |> post(Routes.credential_path(conn, :demote_user, credential.uuid))
               |> json_response(422)
    end

    test "failure when demote member", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)
      user2 = Factory.insert(:credential, %{organization: credential.organization, broker_role_id: 2})

      assert %{"message" => "User is already at Assistant role!"} ==
               conn
               |> post(Routes.credential_path(conn, :demote_user, user2.uuid))
               |> json_response(422)
    end

    test "success when demote member", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)
      user2 = Factory.insert(:credential, %{organization: credential.organization})

      assert %{"message" => "User successfully demoted!"} ==
               conn
               |> post(Routes.credential_path(conn, :demote_user, user2.uuid))
               |> json_response(200)
    end
  end

  describe "POST /accounts/:user_uuid/remove" do
    test "failure when remove self", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)
      user2 = Factory.insert(:credential, %{organization: credential.organization, broker_role_id: 2})

      assert %{"message" => "Sorry, cannot remove own account!"} ==
               conn
               |> post(Routes.credential_path(conn, :remove_user, credential.uuid), %{"successor_uuid" => user2.uuid})
               |> json_response(422)
    end

    test "failure when invalid successor", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)

      assert %{"message" => "Invalid Successor"} ==
               conn
               |> post(Routes.credential_path(conn, :remove_user, credential.uuid), %{"successor_uuid" => Ecto.UUID.autogenerate()})
               |> json_response(422)
    end

    test "success when remove admin", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)
      user2 = Factory.insert(:credential, %{organization: credential.organization})
      user3 = Factory.insert(:credential, %{organization: credential.organization})

      assert %{"message" => "User successfully removed!"} ==
               conn
               |> post(Routes.credential_path(conn, :remove_user, user2.uuid), %{"successor_uuid" => user3.uuid})
               |> json_response(200)
    end

    test "success when remove member", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)
      user2 = Factory.insert(:credential, %{organization: credential.organization, broker_role_id: 2})
      user3 = Factory.insert(:credential, %{organization: credential.organization})

      assert %{"message" => "User successfully removed!"} ==
               conn
               |> post(Routes.credential_path(conn, :remove_user, user2.uuid), %{"successor_uuid" => user3.uuid})
               |> json_response(200)
    end
  end

  describe "POST /accounts/leave" do
    test "success when leave self, chotu becomes admin", %{conn: conn, credential: credential} do
      # given
      Utils.expect_token(credential.uuid)
      user2 = Factory.insert(:credential, %{organization: credential.organization, broker_role_id: 2})

      assert %{"message" => "Left organization successfully!"} ==
               conn
               |> post(Routes.credential_path(conn, :leave_user), %{"successor_uuid" => user2.uuid})
               |> json_response(200)

      # chotu becomes admin
      assert BnApis.Repo.get(BnApis.Accounts.Credential, user2.id).broker_role_id == 1
    end

    test "success when leave self, Their posts are migrated", %{conn: conn, credential: credential} do
      # given
      %{"post_uuid" => post_uuid} = given_rental_property_post(conn, credential)

      # when
      chhotu = Factory.insert(:credential, %{organization: credential.organization, broker_role_id: 2})
      leave_user_api(conn, credential, chhotu)

      # then
      %{"assigned_to_me" => [assigned_to_me]} = fetch_user_posts(conn, chhotu)

      assert assigned_to_me["assigned_to"]["name"] == chhotu.broker.name
      assert post_uuid =~ assigned_to_me["post_uuid"]
    end

    test "success when leave self, Their invoices are migrated", %{conn: conn} do
      # given
      config = Utils.given_story_with_balance(2000)
      {:ok, invoice} = Utils.create_brokerage_invoice(config)
      credential = config.cred

      # when
      chhotu = Factory.insert(:credential, %{organization: credential.organization, broker_role_id: 2})
      leave_user_api(conn, credential, chhotu)

      # then
      %{"invoices" => [fetched_invoice]} = fetch_all_invoices(conn, chhotu)
      assert fetched_invoice["id"] == invoice["id"]
      assert fetched_invoice["broker"]["name"] == chhotu.broker.name
      assert fetched_invoice["broker_id"] == chhotu.broker.id

      refute fetched_invoice["broker_id"] == invoice["broker_id"]
    end

    test "success when leave self, Their site visits are migrated", %{conn: conn, credential: credential} do
      # given
      site_visit = Utils.given_reward_lead(credential, 8) |> IO.inspect()

      # when
      chhotu = Factory.insert(:credential, %{organization: credential.organization, broker_role_id: 2})
      leave_user_api(conn, credential, chhotu)

      # then
      %{"results" => [lead]} = fetch_all_leads(conn, chhotu, "8")
      assert lead["lead"]["id"] == site_visit.id
      assert lead["lead"]["status"]["id"] == 8
      assert lead["story"]["uuid"] == site_visit.story.uuid
      assert lead["lead"]["id"] == site_visit.id
    end

    test "error when successor is self", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)
      user3 = Factory.insert(:credential, %{organization: credential.organization, broker_role_id: 2})

      assert %{"message" => "User to be removed cannot be a successor"} ==
               conn
               |> post(Routes.credential_path(conn, :leave_user), %{"successor_uuid" => credential.uuid})
               |> json_response(422)
    end

    test "error when only one left in org", %{conn: conn, credential: credential} do
      Utils.expect_token(credential.uuid)

      assert %{"message" => "Invalid Successor"} ==
               conn
               |> post(Routes.credential_path(conn, :leave_user), %{"successor_uuid" => Ecto.UUID.autogenerate()})
               |> json_response(422)
    end
  end

  defp fetch_all_leads(conn, credential, status_id_list) do
    Utils.expect_token(credential.uuid)

    conn
    |> get(Routes.v1_rewards_path(conn, :get_leads, status_ids: status_id_list))
    |> json_response(200)
  end

  defp fetch_all_invoices(conn, credential) do
    Utils.expect_token(credential.uuid)

    conn
    |> get(Routes.invoice_path(conn, :fetch_all_invoice_for_broker))
    |> json_response(200)
  end

  defp fetch_user_posts(conn, credential) do
    Utils.expect_token(credential.uuid)

    conn
    |> get(Routes.post_path(conn, :fetch_all_posts))
    |> json_response(200)
  end

  defp leave_user_api(conn, credential, chhotu) do
    Utils.expect_token(credential.uuid)

    conn
    |> post(Routes.credential_path(conn, :leave_user), %{"successor_uuid" => chhotu.uuid})
    |> json_response(200)
  end

  def given_rental_property_post(conn, credential) do
    Utils.expect_token(credential.uuid)
    building = Factory.insert(:building, %{city_id: credential.broker.operating_city})

    body = %{
      "is_bachelor_allowed" => "false",
      "rent_expected" => Integer.to_string(Enum.random(1..1000) * 1000),
      "assigned_user_id" => credential.uuid,
      "building_id" => building.uuid,
      "configuration_type_id" => "8",
      "furnishing_type_id" => "3",
      "commit" => "true",
      "post_type" => "rent",
      "post_sub_type" => "property"
    }

    conn
    |> post(Routes.post_path(conn, :create_post, "rent", "property"), body)
    |> json_response(201)
  end

  def validate_otp_and_signup_user(conn, phone_number, otp, org_id) do
    Utils.mock_verify_otp_sucess_redis(otp)
    Utils.mock_signup_invite_user_redis(phone_number)

    verify_otp_resp =
      conn
      |> post(Routes.v2_credential_path(conn, :verify_otp), %{
        "phone_number" => phone_number,
        "otp" => otp
      })
      |> json_response(200)

    refute verify_otp_resp["signup_completed"]

    conn
    |> post(Routes.v1_credential_path(conn, :signup, organization_id: org_id), %{
      "name" => Faker.Person.first_name(),
      "user_id" => verify_otp_resp["user_id"]
    })
    |> json_response(200)
  end

  defp whitelist_params(phone_number, credential, employee) do
    polygon = Factory.insert(:polygon, %{city_id: credential.broker.operating_city})

    whitelisted_params = %{
      "polygon_uuid" => polygon.uuid,
      "broker_name" => Faker.Person.first_name(),
      "organization_name" => Faker.Person.first_name(),
      "firm_address" => Faker.Address.En.secondary_address(),
      "phone_number" => phone_number,
      "assign_to" => employee.uuid,
      "country_code" => "+91"
    }

    Utils.expect_redis(["otp"], 123)
    Utils.expect_redis(["HINCRBY"], 1)
    Utils.expect_sms("", "assigned to you.")

    Utils.expect_http(:get, "sendbird", 200, %{})
    {:ok, _} = BnApis.Organizations.Broker.whitelist_broker(whitelisted_params, employee.id, %{user_id: employee.id, user_type: "Employee"}, false)
  end

  defp send_invite(conn, payload, credential_uuid) do
    Utils.expect_sms(payload["phone_number"], payload["broker_name"], :sms)
    Utils.expect_token(credential_uuid)

    conn
    |> post(Routes.organization_path(conn, :send_invite), payload)
    |> json_response(200)
  end
end
