defmodule BnApis.Posts.Buckets.Schema.BucketTest do
  use BnApis.DataCase
  alias BnApis.Posts.Buckets.Schema.Bucket
  alias BnApis.Posts.PostType
  alias BnApis.Posts.ConfigurationType

  @valid_params %{
    "name" => "my client",
    "broker_id" => 1,
    "number_of_matching_properties" => 1,
    "last_seen_at" => DateTime.utc_now() |> DateTime.to_unix(),
    "expires_at" => DateTime.utc_now() |> DateTime.to_unix(),
    "archive_at" => DateTime.utc_now() |> DateTime.to_unix(),
    "new_number_of_matching_properties" => 2,
    "archived" => true,
    "filters" => %{
      "location_name" => "Powai",
      "post_type" => PostType.rent().name,
      "configuration_type" => [ConfigurationType.bhk_1().name],
      "locality_id" => 1
    },
    "archived_reason_id" => 1
  }

  describe "buckets changeset/2" do
    @required_fields ["name", "broker_id", "filters"]

    #######################################################################
    ## SUCCESS CASES
    #######################################################################

    test "succeed with only required fields" do
      valid_params = @valid_params |> Map.take(@required_fields)
      name = valid_params["name"]
      assert %Ecto.Changeset{changes: %{name: ^name}, valid?: true} = Bucket.changeset(%Bucket{}, valid_params)
    end

    test "succeed with building_ids" do
      filters = %{
        "location_name" => "Powai",
        "post_type" => PostType.rent().name,
        "configuration_type" => [ConfigurationType.bhk_1().name],
        "building_ids" => [Ecto.UUID.generate(), Ecto.UUID.generate(), Ecto.UUID.generate()]
      }

      valid_params = @valid_params |> Map.put("filters", filters) |> Map.take(@required_fields)
      name = valid_params["name"]
      assert %Ecto.Changeset{changes: %{name: ^name}, valid?: true} = Bucket.changeset(%Bucket{}, valid_params)
    end

    test "succeed with all fields" do
      name = @valid_params["name"]
      assert %Ecto.Changeset{changes: %{name: ^name}, valid?: true} = Bucket.changeset(%Bucket{}, @valid_params)
    end

    test "adds expires_at by default" do
      valid_params = @valid_params |> Map.take(@required_fields)
      name = valid_params["name"]
      assert %Ecto.Changeset{changes: %{name: ^name, expires_at: expires_at}, valid?: true} = Bucket.changeset(%Bucket{}, valid_params)
      assert expires_at - (DateTime.utc_now() |> DateTime.to_unix()) >= 30 * 24 * 60 * 60
    end

    #######################################################################
    ## FAILURE CASES
    #######################################################################

    test "fails with missing required fields" do
      for {key, _} <- @valid_params |> Map.take(@required_fields) do
        invalid_params = @valid_params |> Map.delete(key)
        %Ecto.Changeset{errors: errors, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)

        assert errors == [
                 {String.to_existing_atom(key), {"can't be blank", [validation: :required]}}
               ]
      end

      required_fields = ["post_type", "configuration_type", "location_name"]

      for {key, _} <- @valid_params["filters"] |> Map.take(required_fields) do
        filters = @valid_params["filters"]
        invalid_filters_params = filters |> Map.delete(key)
        invalid_params = Map.put(@valid_params, "filters", invalid_filters_params)
        %Ecto.Changeset{changes: %{filters: %{errors: errors}}, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)

        assert errors == [
                 {String.to_existing_atom(key), {"can't be blank", [validation: :required]}}
               ]
      end
    end

    test "fails with invalid type" do
      for {key, _} <- @valid_params |> Map.take(["last_seen_at", "expires_at", "archive_at"]) do
        invalid_params = @valid_params |> Map.put(key, "invalid_datetime")
        %Ecto.Changeset{errors: errors, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)

        assert errors == [
                 {String.to_existing_atom(key), {"is invalid", [type: :integer, validation: :cast]}}
               ]
      end

      for {key, _} <- @valid_params |> Map.take(["broker_id", "archived_reason_id"]) do
        invalid_params = @valid_params |> Map.put(key, "invalid_integer")
        %Ecto.Changeset{errors: errors, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)

        assert errors == [
                 {String.to_existing_atom(key), {"is invalid", [type: :id, validation: :cast]}}
               ]
      end
    end

    test "fails for invalid filters type" do
      filters = %{
        "location_name" => "Powai",
        "post_type" => 1,
        "configuration_type" => [ConfigurationType.bhk_1().name],
        "locality_id" => 1
      }

      invalid_params = Map.put(@valid_params, "filters", filters)
      %Ecto.Changeset{changes: %{filters: %Ecto.Changeset{errors: errors, valid?: false}}, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)

      assert errors == [post_type: {"is invalid", [type: :string, validation: :cast]}]

      filters = %{
        "location_name" => "Powai",
        ## Not Found PostType
        "post_type" => "not found",
        "configuration_type" => [ConfigurationType.bhk_1().name],
        "locality_id" => 1
      }

      invalid_params = Map.put(@valid_params, "filters", filters)
      %Ecto.Changeset{changes: %{filters: %Ecto.Changeset{errors: errors, valid?: false}}, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)

      assert errors == [post_type: {"invalid post type", [{:validation, :inclusion}, {:enum, ["Rent", "Resale"]}]}]

      filters = %{
        "location_name" => "Powai",
        "post_type" => PostType.rent().name,
        "configuration_type" => [1],
        "locality_id" => 1
      }

      invalid_params = Map.put(@valid_params, "filters", filters)
      %Ecto.Changeset{changes: %{filters: %Ecto.Changeset{errors: errors, valid?: false}}, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)

      assert errors == [configuration_type: {"is invalid", [type: {:array, :string}, validation: :cast]}]

      filters = %{
        "location_name" => "Powai",
        "post_type" => PostType.rent().name,
        ## Not Found ConfigurationType
        "configuration_type" => ["not_found"],
        "locality_id" => 1
      }

      invalid_params = Map.put(@valid_params, "filters", filters)
      %Ecto.Changeset{changes: %{filters: %Ecto.Changeset{errors: errors, valid?: false}}, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)

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
               }
             ]

      filters = %{
        "location_name" => "Powai",
        "post_type" => PostType.rent().name,
        "configuration_type" => 1,
        "locality_id" => 1
      }

      invalid_params = Map.put(@valid_params, "filters", filters)
      %Ecto.Changeset{changes: %{filters: %Ecto.Changeset{errors: errors, valid?: false}}, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)

      assert errors == [configuration_type: {"is invalid", [type: {:array, :string}, validation: :cast]}]

      filters = %{
        "location_name" => "Powai",
        "post_type" => PostType.rent().name,
        ## Not Found ConfigurationType
        "configuration_type" => [],
        "locality_id" => 1
      }

      invalid_params = Map.put(@valid_params, "filters", filters)
      %Ecto.Changeset{changes: %{filters: %Ecto.Changeset{errors: errors, valid?: false}}, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)

      assert errors == [configuration_type: {"should have at least %{count} item(s)", [{:count, 1}, {:validation, :length}, {:kind, :min}, {:type, :list}]}]
    end

    test "fails for multiple locality, longitude,& latitude" do
      filters = %{
        "location_name" => "Powai",
        "post_type" => PostType.rent().name,
        "configuration_type" => [ConfigurationType.bhk_1().name],
        "latitude" => "12.00",
        "longitude" => "1.00",
        "locality_id" => 1
      }

      invalid_params = Map.put(@valid_params, "filters", filters)
      %Ecto.Changeset{changes: %{filters: %Ecto.Changeset{errors: errors, valid?: false}}, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)
      assert errors == [filters: {"only one of google_place_id,locality_id,building_ids is allowed", []}]
    end

    test "fails for more than allowed limit for configuration type" do
      filters = %{
        "location_name" => "Powai",
        "post_type" => PostType.rent().name,
        "configuration_type" => [ConfigurationType.bhk_1().name, ConfigurationType.bhk_2().name, ConfigurationType.bhk_3().name],
        "locality_id" => 1
      }

      invalid_params = Map.put(@valid_params, "filters", filters)
      %Ecto.Changeset{changes: %{filters: %Ecto.Changeset{errors: errors, valid?: false}}, valid?: false} = Bucket.changeset(%Bucket{}, invalid_params)
      assert errors == [configuration_type: {"should have at most %{count} item(s)", [{:count, 2}, {:validation, :length}, {:kind, :max}, {:type, :list}]}]
    end
  end

  describe "buckets update_changeset/2" do
    @editable_fields ["number_of_matching_properties", "last_seen_at", "expires_at", "archive_at", "archived", "archived_reason_id"]

    #######################################################################
    ## SUCCESS CASES
    #######################################################################

    test "succeed with editable fields" do
      valid_params = @valid_params |> Map.take(@editable_fields)
      assert %Ecto.Changeset{valid?: true} = Bucket.update_changeset(%Bucket{}, valid_params)
    end

    #######################################################################
    ## FAILURE CASES
    #######################################################################

    test "no update for fields apart from allowed editable_fields" do
      valid_params = @valid_params |> Map.drop(@editable_fields)
      assert %Ecto.Changeset{changes: changes, valid?: true} = Bucket.update_changeset(%Bucket{}, valid_params)
      ## No changes as expected
      assert changes == %{}
    end
  end
end
