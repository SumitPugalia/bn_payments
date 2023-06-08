defmodule BnApisWeb.V1.Posts.BucketControllerTest do
  use BnApisWeb.ConnCase, async: true

  alias BnApis.Tests.Utils
  alias BnApis.Posts.PostType
  alias BnApis.Posts.ConfigurationType
  alias BnApis.Helpers.Redis

  setup %{conn: conn} do
    Redis.q(["FLUSHALL"])
    %{token: token, broker_id: broker_id} = Utils.get_broker_token()
    {:ok, conn: put_req_header(conn, "accept", "application/json"), token: token, broker_id: broker_id}
  end

  describe "create" do
    @valid_params %{
      "name" => "my client",
      "filters" => %{
        "location_name" => "Powai",
        "post_type" => 1,
        "configuration_type" => [1, 2],
        "google_place_id" => "ChIJndMI5-3F5zsRbRM_-mTnGtg"
      }
    }

    test "success with no posts", %{conn: conn, token: token} do
      bucket =
        conn
        |> add_auth_header(token)
        |> post(Routes.bucket_path(conn, :create, %{}), @valid_params)
        |> json_response(200)

      assert is_integer(bucket["id"])
      assert bucket["new_number_of_matching_properties"] == 0
      assert bucket["number_of_matching_properties"] == 0
    end

    test "success with a post present", %{conn: conn, token: token} do
      %{credential_id: credential_id} = Utils.get_broker_token()
      _created_post = Utils.given_posts(:rental_property, credential_id, %{"inserted_at" => NaiveDateTime.utc_now() |> NaiveDateTime.add(-60 * 24, :second)})

      valid_params = %{
        "name" => "my client",
        "filters" => %{
          "location_name" => "Powai",
          "post_type" => 1,
          "configuration_type" => [1, 2],
          "locality_id" => 1
        }
      }

      bucket =
        conn
        |> add_auth_header(token)
        |> post(Routes.bucket_path(conn, :create, %{}), valid_params)
        |> json_response(200)

      assert is_integer(bucket["id"])
      assert bucket["new_number_of_matching_properties"] == 1
      assert bucket["number_of_matching_properties"] == 1
    end

    test "success for same name but different broker", %{conn: conn, token: token} do
      ## Broker One
      bucket =
        conn
        |> add_auth_header(token)
        |> post(Routes.bucket_path(conn, :create, %{}), @valid_params)
        |> json_response(200)

      assert is_integer(bucket["id"])

      ## Same Name request from different broker
      %{token: token} = Utils.get_broker_token()

      bucket =
        conn
        |> add_auth_header(token)
        |> post(Routes.bucket_path(conn, :create, %{}), @valid_params)
        |> json_response(200)

      assert is_integer(bucket["id"])
    end

    test "success for same name for the same broker", %{conn: conn, token: token} do
      ## Broker One
      bucket =
        conn
        |> add_auth_header(token)
        |> post(Routes.bucket_path(conn, :create, %{}), @valid_params)
        |> json_response(200)

      assert is_integer(bucket["id"])

      ## Same Name request
      bucket =
        conn
        |> add_auth_header(token)
        |> post(Routes.bucket_path(conn, :create, %{}), @valid_params)
        |> json_response(200)

      assert is_integer(bucket["id"])
    end

    test "fails if token is invalid", %{conn: conn, token: _token} do
      response =
        conn
        |> add_auth_header("any token")
        |> post(Routes.bucket_path(conn, :create, %{}), @valid_params)
        |> response(401)

      assert response == "{\"message\":\"You are not authorized to make this call\",\"invalidSession\":true}"
    end

    test "fails if token is missing", %{conn: conn, token: _token} do
      response =
        conn
        |> post(Routes.bucket_path(conn, :create, %{}), @valid_params)
        |> response(401)

      assert response == "{\"message\":\"You are not authorized to make this call\",\"invalidSession\":true}"
    end

    test "fails for multiple locality", %{conn: conn, token: token} do
      invalid_params =
        Map.put(@valid_params, "filters", %{
          "post_type" => PostType.rent().name,
          "configuration_type" => [ConfigurationType.bhk_1().id],
          "google_place_id" => "ChIJndMI5-3F5zsRbRM_-mTnGtg",
          "locality_id" => 1,
          "location_name" => "Powai"
        })

      response =
        conn
        |> add_auth_header(token)
        |> post(Routes.bucket_path(conn, :create, %{}), invalid_params)
        |> json_response(422)

      assert response == %{"errors" => ":filters->:filters = only one of google_place_id,locality_id is allowed"}
    end

    test "fails for invalid filters", %{conn: conn, token: token} do
      invalid_params =
        Map.put(@valid_params, "filters", %{
          "post_type" => 4,
          "configuration_type" => "invalid_type",
          "google_place_id" => "ChIJndMI5-3F5zsRbRM_-mTnGtg",
          "location_name" => "Powai"
        })

      response =
        conn
        |> add_auth_header(token)
        |> post(Routes.bucket_path(conn, :create, %{}), invalid_params)
        |> json_response(422)

      assert response == %{"errors" => ":filters->:configuration_type = is invalid | :filters->:post_type = invalid post type"}

      invalid_params =
        Map.put(@valid_params, "filters", %{
          "post_type" => 4,
          "configuration_type" => ["invalid_params"],
          "google_place_id" => "ChIJndMI5-3F5zsRbRM_-mTnGtg",
          "location_name" => "Powai"
        })

      response =
        conn
        |> add_auth_header(token)
        |> post(Routes.bucket_path(conn, :create, %{}), invalid_params)
        |> json_response(422)

      assert response == %{"errors" => ":filters->:configuration_type = invalid configuration type | :filters->:post_type = invalid post type"}

      invalid_params =
        Map.put(@valid_params, "filters", %{
          "post_type" => 4,
          "configuration_type" => [],
          "google_place_id" => "ChIJndMI5-3F5zsRbRM_-mTnGtg",
          "location_name" => "Powai"
        })

      response =
        conn
        |> add_auth_header(token)
        |> post(Routes.bucket_path(conn, :create, %{}), invalid_params)
        |> json_response(422)

      assert response == %{"errors" => ":filters->:configuration_type = should have at least 1 item(s) | :filters->:post_type = invalid post type"}
    end
  end

  describe "index" do
    test "success for empty bucket list", %{conn: conn, token: token} do
      response =
        conn
        |> add_auth_header(token)
        |> get(Routes.bucket_path(conn, :index), %{p: 1})
        |> json_response(200)

      assert %{"buckets" => [], "has_more_buckets" => false} = response
    end

    test "success for bucket list", %{conn: conn, token: token, broker_id: broker_id} do
      bucket = Utils.given_bucket(:locality_id, broker_id, %{"name" => "my bucket name"})

      response =
        conn
        |> add_auth_header(token)
        |> get(Routes.bucket_path(conn, :index), %{p: 1})
        |> json_response(200)

      assert %{"buckets" => buckets, "has_more_buckets" => false, "badge_count" => 0} = response
      assert length(buckets) == 1
      received_bucket = hd(buckets)
      assert received_bucket["filters"]["post_type"] == bucket.filters.post_type
      assert received_bucket["filters"]["configuration_type"] == bucket.filters.configuration_type
      assert received_bucket["filters"]["location_name"] == bucket.filters.location_name
      assert received_bucket["new_number_of_matching_properties"] == 0
      assert received_bucket["number_of_matching_properties"] == 0

      refute received_bucket["last_seen_at"]
      refute received_bucket["expires_at"]
      refute received_bucket["archive_at"]
      refute received_bucket["archived"]
    end

    test "success for bucket list with posts", %{conn: conn, token: token, broker_id: broker_id} do
      %{credential_id: credential_id} = Utils.get_broker_token()
      name = "bucket_detail"
      _created_post = Utils.given_posts(:rental_property, credential_id, %{"inserted_at" => NaiveDateTime.utc_now() |> NaiveDateTime.add(-60 * 60 * 24 * 2, :second)})
      created_bucket = Utils.given_bucket(:locality_id, broker_id, %{"name" => name})

      response =
        conn
        |> add_auth_header(token)
        |> get(Routes.bucket_path(conn, :index), %{p: 1})
        |> json_response(200)

      assert %{"buckets" => buckets, "has_more_buckets" => false, "badge_count" => 1} = response
      assert length(buckets) == 1
      received_bucket = hd(buckets)
      assert received_bucket["filters"]["post_type"] == created_bucket.filters.post_type
      assert received_bucket["filters"]["configuration_type"] == created_bucket.filters.configuration_type
      assert received_bucket["filters"]["location_name"] == created_bucket.filters.location_name
      assert received_bucket["new_number_of_matching_properties"] == 1
      assert received_bucket["number_of_matching_properties"] == 1

      refute received_bucket["last_seen_at"]
      refute received_bucket["expires_at"]
      refute received_bucket["archive_at"]
      refute received_bucket["archived"]
    end
  end

  describe "bucket_details" do
    test "success", %{conn: conn, token: token, broker_id: broker_id} do
      bucket = Utils.given_bucket(:locality_id, broker_id, %{"name" => "bucket_details"})

      response =
        conn
        |> add_auth_header(token)
        |> get(Routes.bucket_path(conn, :bucket_details, bucket.id))
        |> json_response(200)

      assert response == %{"has_more_posts" => false, "posts" => [], "total_count" => 0}
    end

    test "fails for non existing bucket", %{conn: conn, token: token} do
      response =
        conn
        |> add_auth_header(token)
        |> get(Routes.bucket_path(conn, :bucket_details, 1_000))
        |> json_response(422)

      assert response == %{"message" => "bucket_not_found"}
    end
  end

  describe "update" do
    test "to referesh", %{conn: conn, token: token, broker_id: broker_id} do
      bucket = Utils.given_bucket(:locality_id, broker_id, %{"name" => "bucket_details"})

      response =
        conn
        |> add_auth_header(token)
        |> patch(Routes.bucket_path(conn, :update, bucket.id), %{})
        |> json_response(200)

      assert response == %{"message" => "Successfully updated"}
    end

    test "to delete", %{conn: conn, token: token, broker_id: broker_id} do
      bucket = Utils.given_bucket(:locality_id, broker_id, %{"name" => "bucket_details"})

      response =
        conn
        |> add_auth_header(token)
        |> patch(Routes.bucket_path(conn, :update, bucket.id), %{"archive" => true, "archived_reason_id" => 24})
        |> json_response(200)

      assert response == %{"message" => "Successfully deleted"}
    end
  end

  defp add_auth_header(conn, token) do
    conn |> put_req_header("authorization", "Bearer #{token}")
  end
end
