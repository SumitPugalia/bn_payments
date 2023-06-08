defmodule BnApis.Posts.Buckets.BucketsTest do
  use BnApis.DataCase
  alias BnApis.Tests.Utils
  alias BnApis.Posts.Buckets.Buckets
  alias BnApis.Helpers.Redis

  setup_all do
    Redis.q(["FLUSHALL"])
    :ok
  end

  describe "buckets create/2" do
    @valid_params %{
      "name" => "my client",
      "filters" => %{
        "post_type" => 1,
        "location_name" => "Powai",
        "configuration_type" => [1],
        "google_place_id" => "ChIJndMI5-3F5zsRbRM_-mTnGtg"
      }
    }

    #######################################################################
    ## SUCCESS CASE
    #######################################################################

    test "succeed with required fields" do
      broker = Utils.given_broker()
      valid_params = @valid_params
      assert {:ok, bucket} = Buckets.create(valid_params, broker.id)
      ## Converts google_place_id to latitude & longitude
      assert bucket.filters.latitude == "19.0522115"
      assert bucket.filters.longitude == "72.900522"
    end

    test "succeed with building ids" do
      filters = %{
        "location_name" => "Powai",
        "post_type" => 1,
        "configuration_type" => [1],
        "building_ids" => [Ecto.UUID.generate(), Ecto.UUID.generate(), Ecto.UUID.generate()]
      }

      broker = Utils.given_broker()
      valid_params = @valid_params |> Map.put("filters", filters)
      assert {:ok, bucket} = Buckets.create(valid_params, broker.id)
      assert bucket.filters.building_ids == filters["building_ids"]
    end

    test "succeed for same name for the different broker" do
      ## Broker One
      broker = Utils.given_broker()
      valid_params = @valid_params
      assert {:ok, _bucket} = Buckets.create(valid_params, broker.id)

      ## Broker Two : Same Name request
      broker = Utils.given_broker()
      valid_params = @valid_params
      assert {:ok, _bucket} = Buckets.create(valid_params, broker.id)
    end

    test "succeed for same name for the same broker" do
      ## Broker One
      broker = Utils.given_broker()
      valid_params = @valid_params
      assert {:ok, _bucket} = Buckets.create(valid_params, broker.id)

      ## Same Name request
      valid_params = @valid_params
      assert {:ok, _bucket} = Buckets.create(valid_params, broker.id)
    end

    #######################################################################
    ## FAILURE CASES
    #######################################################################

    test "fails for non-existent broker_id" do
      valid_params = @valid_params
      assert {:error, %Ecto.Changeset{errors: errors}} = Buckets.create(valid_params, 10_000)
      assert errors == [broker: {"does not exist", [{:constraint, :assoc}, {:constraint_name, "buckets_broker_id_fkey"}]}]
    end

    test "fails when external google api call fails" do
      filters = %{
        "location_name" => "Powai",
        "post_type" => 1,
        "configuration_type" => [1],
        "google_place_id" => "invalid_google_id"
      }

      valid_params = @valid_params |> Map.put("filters", filters)
      assert {:error, error} = Buckets.create(valid_params, 1)
      assert error == "failed to convert google_place_id"
    end

    test "fails when invalid post_type & configuration_type are sent" do
      filters = %{
        "location_name" => "Powai",
        "post_type" => 4,
        "configuration_type" => ["invalid"],
        "locality_id" => 1
      }

      valid_params = @valid_params |> Map.put("filters", filters)
      assert {:error, %Ecto.Changeset{changes: %{filters: %{errors: errors}}}} = Buckets.create(valid_params, 1)

      assert errors == [
               configuration_type: {
                 "invalid configuration type",
                 [
                   {:validation, :subset},
                   {:enum,
                    [
                      "Studio / 1 RK",
                      "1 BHK",
                      "1.5 BHK",
                      "2 BHK",
                      "2.5 BHK",
                      "3 BHK",
                      "3.5 BHK",
                      "4 BHK",
                      "4+ BHK",
                      "Plot",
                      "Villa",
                      "Commercial",
                      "Office",
                      "Farmland",
                      "Commercial-Fractional"
                    ]}
                 ]
               },
               post_type: {"invalid post type", [{:validation, :inclusion}, {:enum, ["Rent", "Resale"]}]}
             ]
    end
  end

  describe "buckets list/2" do
    #######################################################################
    ## SUCCESS CASES
    #######################################################################

    test "success for listing empty buckets" do
      assert %{buckets: [], has_more_buckets: false, badge_count: 0} == Buckets.list(1, 1)
    end

    test "success for listing buckets with google_place_id" do
      broker = Utils.given_broker()
      broker_id = broker.id
      name = "bucket_detail"
      bucket = Utils.given_bucket(:google_place_id, broker_id, %{"name" => name})

      assert %{buckets: buckets, has_more_buckets: false} = Buckets.list(broker.id, 1)
      assert length(buckets) == 1
      assert hd(buckets).name == name
      assert hd(buckets).id == bucket.id
      assert is_binary(hd(buckets).filters.latitude)
      assert is_binary(hd(buckets).filters.longitude)
    end

    # @moduletag capture_log: true
    test "success for listing buckets with locality_id" do
      %{broker_id: broker_id, credential_id: credential_id} = Utils.get_broker_token()
      name = "bucket_detail"
      _created_post = Utils.given_posts(:rental_property, credential_id, %{"inserted_at" => NaiveDateTime.utc_now() |> NaiveDateTime.add(-60 * 60 * 24 * 2, :second)})
      created_bucket = Utils.given_bucket(:locality_id, broker_id, %{"name" => name})

      assert %{buckets: [bucket], has_more_buckets: false, badge_count: badge_count} = Buckets.list(broker_id, 1)
      assert bucket.id == created_bucket.id
      assert bucket.number_of_matching_properties == 1
      assert bucket.new_number_of_matching_properties == 1
      assert badge_count == 1

      ## View the bucket resets the count
      assert {:ok, {[_post], 1, false}} = Buckets.get_bucket_details(broker_id, created_bucket.id, 1)

      assert %{buckets: [bucket], has_more_buckets: false, badge_count: badge_count} = Buckets.list(broker_id, 1)
      assert bucket.name == name
      assert bucket.id == created_bucket.id
      assert bucket.number_of_matching_properties == 1
      assert bucket.new_number_of_matching_properties == 0
      assert badge_count == 0

      ## create more posts
      _created_post = Utils.given_posts(:rental_property, credential_id, %{"inserted_at" => NaiveDateTime.utc_now() |> NaiveDateTime.add(10, :second)})
      _created_post = Utils.given_posts(:rental_property, credential_id, %{"inserted_at" => NaiveDateTime.utc_now() |> NaiveDateTime.add(15, :second)})

      assert %{buckets: [bucket], has_more_buckets: false} = Buckets.list(broker_id, 1)
      assert bucket.name == name
      assert bucket.id == created_bucket.id
      assert bucket.number_of_matching_properties == 3
      assert bucket.new_number_of_matching_properties == 2

      Buckets.get_bucket_details(broker_id, created_bucket.id, 1)
    end

    test "success for listing buckets with building_ids" do
      building = BnApis.Repo.get_by(BnApis.Buildings.Building, name: "Test Castle")
      %{broker_id: broker_id, credential_id: credential_id} = Utils.get_broker_token()
      name = "bucket_detail"
      _created_post = Utils.given_posts(:rental_property, credential_id, %{"inserted_at" => NaiveDateTime.utc_now() |> NaiveDateTime.add(-60 * 60 * 24 * 2, :second)})
      created_bucket = Utils.given_bucket(:building_ids, broker_id, %{"name" => name, "building_ids" => [building.uuid, building.uuid, building.uuid]})

      assert %{buckets: [bucket], has_more_buckets: false, badge_count: badge_count} = Buckets.list(broker_id, 1)
      assert bucket.id == created_bucket.id
      assert bucket.number_of_matching_properties == 1
      assert bucket.new_number_of_matching_properties == 1
      assert badge_count == 1

      ## View the bucket resets the count
      assert {:ok, {[_post], 1, false}} = Buckets.get_bucket_details(broker_id, created_bucket.id, 1)

      assert %{buckets: [bucket], has_more_buckets: false, badge_count: badge_count} = Buckets.list(broker_id, 1)
      assert bucket.name == name
      assert bucket.id == created_bucket.id
      assert bucket.number_of_matching_properties == 1
      assert bucket.new_number_of_matching_properties == 0
      assert badge_count == 0

      ## create more posts
      _created_post = Utils.given_posts(:rental_property, credential_id, %{"inserted_at" => NaiveDateTime.utc_now() |> NaiveDateTime.add(10, :second)})
      _created_post = Utils.given_posts(:rental_property, credential_id, %{"inserted_at" => NaiveDateTime.utc_now() |> NaiveDateTime.add(15, :second)})

      assert %{buckets: [bucket], has_more_buckets: false} = Buckets.list(broker_id, 1)
      assert bucket.name == name
      assert bucket.id == created_bucket.id
      assert bucket.number_of_matching_properties == 3
      assert bucket.new_number_of_matching_properties == 2

      Buckets.get_bucket_details(broker_id, created_bucket.id, 1)
    end
  end

  describe "buckets get_bucket_details/3" do
    test "success for given bucket with no posts" do
      broker = Utils.given_broker()
      broker_id = broker.id
      bucket = Utils.given_bucket(:locality_id, broker_id, %{"name" => "bucket_detail"})
      assert {:ok, {[], 0, false}} = Buckets.get_bucket_details(broker_id, bucket.id, 1)
    end

    test "success for given bucket with posts" do
      %{broker_id: broker_id, credential_id: credential_id} = Utils.get_broker_token()
      created_post = Utils.given_posts(:rental_property, credential_id)
      bucket = Utils.given_bucket(:locality_id, broker_id, %{"name" => "bucket_detail"})
      assert {:ok, {[post], 1, false}} = Buckets.get_bucket_details(broker_id, bucket.id, 1)
      assert post.uuid == created_post.uuid
    end

    test "success for given bucket with multiple posts" do
      %{broker_id: broker_id, credential_id: credential_id} = Utils.get_broker_token()
      created_post_1 = Utils.given_posts(:rental_property, credential_id, %{"inserted_at" => NaiveDateTime.utc_now() |> NaiveDateTime.add(-60 * 60 * 24 * 2, :second)})
      created_post_2 = Utils.given_posts(:rental_property, credential_id, %{"inserted_at" => NaiveDateTime.utc_now() |> NaiveDateTime.add(-60 * 60 * 24 * 1, :second)})
      bucket = Utils.given_bucket(:locality_id, broker_id, %{"name" => "bucket_detail"})
      assert {:ok, {[post1, post2], 2, false}} = Buckets.get_bucket_details(broker_id, bucket.id, 1)
      ## sorted posts
      assert post1.uuid == created_post_2.uuid
      assert post2.uuid == created_post_1.uuid
    end
  end
end
