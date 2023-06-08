defmodule BnApisWeb.PostView do
  use BnApisWeb, :view
  alias BnApisWeb.{PostView, CallLogView}
  alias BnApis.Posts
  alias BnApis.Posts.PostSubType
  alias BnApis.Posts.PostType
  alias BnApis.Posts.ConfigurationType
  alias BnApis.Posts.FurnishingType
  alias BnApis.Posts.FloorType
  alias BnApis.Helpers.{S3Helper, Time}

  def render("index.json", %{posts: posts}) do
    %{data: render_many(posts, PostView, "post.json")}
  end

  def render("profile_details.json", %{
        posts: posts,
        has_more_posts: has_more_posts,
        broker_credential: credential,
        call_logs_with_broker: call_logs,
        blocked: blocked
      }) do
    profile_details = %{
      has_more_posts: has_more_posts,
      blocked: blocked,
      posts: posts |> Enum.map(fn %{post_in_context: pic} -> pic end)
    }

    case credential do
      nil ->
        profile_details

      %{active: false} ->
        profile_details

      %{active: true, broker: broker} ->
        profile_image = broker.profile_image

        profile_image = if !is_nil(profile_image) && !is_nil(profile_image["url"]), do: S3Helper.get_imgix_url(profile_image["url"])

        %{
          profile: %{
            profile_pic_url: profile_image,
            phone_number: credential.phone_number,
            name: broker.name,
            org_name: credential.organization.name
          },
          call_logs:
            call_logs
            |> Enum.map(fn call_log ->
              render_one(call_log, CallLogView, "call_log.json")
            end)
        }
        |> Map.merge(profile_details)
    end
  end

  def render("outstanding_matches_with_broker.json", %{
        posts: posts,
        has_more_posts: has_more_posts
      }) do
    %{
      has_more_posts: has_more_posts,
      posts: posts |> Enum.map(fn %{post_in_context: pic} -> pic end)
    }
  end

  def render("show.json", %{post: post}) do
    %{data: render_one(post, PostView, "post.json")}
  end

  def render("common_post_match_response.json", %{post: post}) do
    # in ms
    expires_in = (post["expires_in"] || 1) * 1000
    # within 1 day
    show_expires_in = expires_in > Time.now_to_epoch() and expires_in < Time.expiration_time(24 * 60 * 60)

    more_post_data = %{
      "type" => PostType.get_by_id(post["type"]),
      "sub_type" => PostSubType.get_by_id(post["sub_type"]),
      "show_expires_in" => show_expires_in
    }

    post = post |> Map.merge(more_post_data)

    post =
      case post["assigned_to"] do
        nil ->
          post

        %{"profile_pic_url" => %{"url" => url}} = assigned_to ->
          profile_image = S3Helper.get_imgix_url(url) <> "?fit=facearea&facepad=1.75&w=200&h=200"

          post
          |> Map.merge(%{
            "assigned_to" => %{assigned_to | "profile_pic_url" => profile_image}
          })

        %{"profile_pic_url" => _} ->
          post
      end

    if post["sub_type"].id == PostSubType.property().id do
      info = property_info(post["building_name"], post["configuration_type_id"], more_post_data["type"][:name])
      post |> Map.merge(%{"info" => info})
    else
      info = client_info(post["building_names"], post["configuration_type_ids"], more_post_data["type"][:name])
      post |> Map.merge(%{"info" => info})
    end
  end

  @doc """
  {
    "uuid": "68ab78d4-0761-11e9-81b8-a31d9820eb3f",
    "title": "Rental Client", // We will keep this field to have more control on copy
    "type": {
        "name": "Rent",
        "id": 1
    },
    "sub_type": {
        "name": "Client",
        "id": 2
    },
    "info": "1/2 BHK required in Lake Florence, Lake Primrose",
    "sub_info": [
        "5000 Rs",
        "Bachelor Not Allowed",
        "Fully Furnished",
    ],
    "notes": "Something here",
    "new_match_count": 4,
    "name": "Sarah Connor will save John!",
    "max_rent": 5000,
    "match_count": 3,
    "is_bachelor": false,
    "inserted_at": 1545645056,
    "show_expires_in": true,
    "expires_in": 2343243,
    "assigned_to": {
        "uuid": "b443a67e-f891-11e8-a237-e7632bf3485b",
        "profile_pic_url": "Absolute URL to profile pic",
        "name": "Arpit",
    }
  }
  """
  def render("generic_post.json", %{post: post}) do
    post = render_one(post, PostView, "common_post_match_response.json")

    post =
      if post["type"].id == PostType.resale().id do
        sub_info = [
          %{
            "text" => "#{format_money(post["price"] || post["max_budget"])}"
          },
          %{
            "text" => "#{post["parking"] || post["min_parking"]} parking"
          },
          %{
            "text" => "#{post["carpet_area"] || post["min_carpet_area"]} Sq ft"
          },
          %{
            "text" => "#{floor_name(post["floor_type_id"]) || floor_names(post["floor_type_ids"])}"
          }
        ]

        post |> Map.merge(%{"sub_info" => sub_info})
      else
        bachelor_text = if post["is_bachelor"] || post["is_bachelor_allowed"], do: "Bachelor", else: "Family"

        sub_info = [
          %{
            "text" => "#{format_money(post["rent_expected"] || post["max_rent"])}"
          },
          %{
            "text" => "#{bachelor_text}"
          },
          %{
            "text" => "#{furnishing_name(post["furnishing_type_id"]) || furnishing_names(post["furnishing_type_ids"])}"
          }
        ]

        post |> Map.merge(%{"sub_info" => sub_info})
      end

    remove_extra_keys(post)
  end

  def render("post.json", %{post: post}) do
    post = render_one(post, PostView, "generic_post.json")

    post
    |> Map.delete("call_log_time")
  end

  def render("archived_post.json", %{post: post}) do
    post = render_one(post, PostView, "post.json")

    expires_in =
      case post["expires_in"] do
        nil ->
          Time.expiration_time(2 * 60 * 60)

        expires_in ->
          expires_in
      end

    is_restorable = Time.now_to_epoch() < Time.extend_time(expires_in, Posts.grace_period())
    post |> Map.merge(%{"is_restorable" => is_restorable})
  end

  def remove_extra_keys(post) do
    post
    |> Map.delete("building_name")
    |> Map.delete("building_names")
    |> Map.delete("matching_building_names")
    |> Map.delete("matching_configuration_type_ids")
    |> Map.delete("assigned_to_me")
    |> Map.delete("archived")
    |> Map.delete("price")
    |> Map.delete("max_budget")
    |> Map.delete("parking")
    |> Map.delete("min_parking")
    |> Map.delete("carpet_area")
    |> Map.delete("min_carpet_area")
    |> Map.delete("floor_type_id")
    |> Map.delete("floor_type_ids")
    |> Map.delete("rent_expected")
    |> Map.delete("max_rent")
    |> Map.delete("is_bachelor")
    |> Map.delete("is_bachelor_allowed")
    |> Map.delete("furnishing_type_id")
    |> Map.delete("furnishing_type_ids")
    |> Map.delete("edit_distances")
    |> Map.delete("edit_distance")
    |> Map.delete("assigned_user_id")
  end

  defp format_money(rupees) when is_nil(rupees), do: "-"
  defp format_money(rupees) when is_binary(rupees), do: format_money(rupees |> String.to_integer())

  defp format_money(rupees) when rupees < 100_000 do
    rupee_string = (rupees / :math.pow(10, 3)) |> :erlang.float_to_binary([:compact, {:decimals, 2}]) |> String.trim_trailing(".0")

    "#{rupee_string} K"
  end

  defp format_money(rupees) when rupees < 10_000_000 do
    rupee_string = (rupees / :math.pow(10, 5)) |> :erlang.float_to_binary([:compact, {:decimals, 2}]) |> String.trim_trailing(".0")

    "#{rupee_string} L"
  end

  defp format_money(rupees) do
    rupee_string = (rupees / :math.pow(10, 7)) |> :erlang.float_to_binary([:compact, {:decimals, 2}]) |> String.trim_trailing(".0")

    "#{rupee_string} Cr"
  end

  defp property_info(building_name, configuration_type_id, post_type) do
    config_name = ConfigurationType.get_by_id(configuration_type_id).name
    "#{config_name} available for #{post_type} in #{building_name}"
  end

  defp client_info(building_names, configuration_type_ids, post_type)
       when is_nil(building_names) or is_nil(configuration_type_ids) or is_nil(post_type),
       do: nil

  defp client_info(building_names, configuration_type_ids, post_type) do
    config_names =
      configuration_type_ids
      |> Enum.map(&ConfigurationType.get_by_id(&1).name)
      |> Enum.join("/")
      |> String.replace(" BHK", "")
      |> return_config_name

    building_names = Enum.join(building_names, ", ")

    "#{config_names} required for #{post_type} in #{building_names}"
  end

  def return_config_name(names) when names == "Studio / 1 RK", do: "Studio / 1 RK"
  def return_config_name(names), do: names |> Kernel.<>(" BHK")

  defp floor_name(floor_type_id) when is_nil(floor_type_id), do: nil

  defp floor_name(floor_type_id) when is_integer(floor_type_id) do
    FloorType.get_by_id(floor_type_id).name
  end

  defp floor_names(floor_type_ids) when is_nil(floor_type_ids), do: nil

  defp floor_names(floor_type_ids) when is_list(floor_type_ids) do
    floor_type_ids
    |> Enum.map(&FloorType.get_by_id(&1).name)
    |> Enum.join("/")
  end

  defp furnishing_name(furnishing_type_id) when is_nil(furnishing_type_id), do: nil

  defp furnishing_name(furnishing_type_id) when is_integer(furnishing_type_id) do
    FurnishingType.get_by_id(furnishing_type_id).name
  end

  defp furnishing_names(furnishing_type_ids) when is_nil(furnishing_type_ids), do: nil

  defp furnishing_names(furnishing_type_ids) when is_list(furnishing_type_ids) do
    furnishing_type_ids
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.join("-")
    |> FurnishingType.get_combined_name()
  end
end
