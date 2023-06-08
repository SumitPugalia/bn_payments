defmodule BnApis.Posts.MatchHelper do
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Buildings.Building
  alias BnApis.Helpers.{S3Helper, Time}
  alias BnApis.Posts.{RentalMatch, ResaleMatch, MatchReadStatus}
  alias BnApis.Posts.{PostType, PostSubType, ConfigurationType, FurnishingType, FloorType}
  alias BnApis.Accounts.Credential
  alias BnApis.CallLogs.CallLog
  alias BnApis.Posts.ResalePropertyPost

  @post_type_rent_id PostType.rent().id
  @post_type_resale_id PostType.resale().id
  @post_subtype_property_id PostSubType.property().id
  @post_subtype_client_id PostSubType.client().id

  # TODO: Hardcoded same for all location as of now.
  # Rental: [rent, bachelor, furnishing]
  # Resale: [price, area, parking, floor]
  @rental_weight_vector [200, 80, 50]
  @resale_weight_vector [500, 200, 150, 80]

  def get_assigned_user(assigned_user) do
    profile_pic_url =
      case assigned_user.broker do
        nil -> nil
        %{profile_image: nil} -> nil
        %{profile_image: %{"url" => nil}} -> nil
        %{profile_image: %{"url" => url}} -> S3Helper.get_imgix_url(url) <> "?fit=facearea&facepad=1.75&w=200&h=200"
      end

    %{
      uuid: assigned_user.uuid,
      name: assigned_user.broker.name,
      profile_pic_url: profile_pic_url,
      org_name: assigned_user.organization.name,
      phone_number: assigned_user.phone_number
    }
  end

  def get_assigned_owner(assigned_owner) do
    if Ecto.assoc_loaded?(assigned_owner) and not is_nil(assigned_owner) do
      cc = if is_nil(assigned_owner.country_code), do: "+91", else: assigned_owner.country_code

      %{
        id: assigned_owner.id,
        uuid: assigned_owner.uuid,
        name: assigned_owner.name,
        email: assigned_owner.email,
        country_code: cc,
        phone_number: assigned_owner.phone_number
      }
    else
      %{}
    end
  end

  def common_post_keys(rp, user_id, post_type_id, post_subtype_id, rm \\ nil) do
    assigned_to =
      if !is_nil(rp.assigned_user) do
        get_assigned_user(rp.assigned_user)
      else
        %{}
      end

    info_text =
      if post_subtype_id == PostSubType.property().id do
        property_info(rp.building.name, rp.configuration_type_id, PostType.get_by_id(post_type_id).name)
      else
        client_info(
          get_only_matching_building_names(user_id, rp, post_type_id, rm),
          get_only_matching_config_ids(user_id, rp, post_type_id, rm),
          PostType.get_by_id(post_type_id).name
        )
      end

    # in ms
    expires_in = rp.expires_in |> Time.naive_to_epoch() || 1
    # within 1 day
    show_expires_in = expires_in > Time.now_to_epoch() and expires_in < Time.expiration_time(24 * 60 * 60)

    post =
      %{
        assigned_to: assigned_to,
        expires_in: rp.expires_in |> Time.naive_to_epoch_in_sec(),
        info: info_text,
        inserted_at: rp.inserted_at |> Time.naive_to_epoch_in_sec(),
        notes: rp.notes,
        show_expires_in: show_expires_in,
        sub_type: PostSubType.get_by_id(post_subtype_id),
        title: post_title(post_type_id, post_subtype_id),
        type: PostType.get_by_id(post_type_id),
        updation_time: rp.updation_time |> Time.naive_to_epoch_in_sec(),
        post_uuid: rp.uuid,
        uuid: create_uuid(rp, post_type_id, post_subtype_id)
      }
      |> Map.merge(add_extra_keys(rp, post_type_id, post_subtype_id))

    if post_subtype_id == @post_subtype_client_id do
      post
      |> Map.merge(%{
        name: rp.name
      })
    else
      post
    end
  end

  def structured_post_match_keys(rm, user_id, rp, post_type_id, post_subtype_id) do
    post = common_post_keys(rp, user_id, post_type_id, post_subtype_id, rm)

    post =
      post
      |> Map.merge(%{
        match_id: rm.id,
        is_unlocked: rm.is_unlocked,
        perfect_match: rm.edit_distance |> Decimal.to_float() == 0,
        # read: not is_nil(rm.outgoing_call_log_id),
        sub_info: create_match_sub_info(rm, rp, post_type_id)
      })

    rm_inserted_at = rm.inserted_at |> Time.naive_to_epoch_in_sec()
    rp_updated_at = rp.updated_at |> Time.naive_to_epoch_in_sec()

    updation_time =
      case post.updation_time do
        nil -> rp_updated_at
        updation_time -> updation_time
      end

    sorting_time =
      case post.updation_time do
        nil -> rm_inserted_at
        updation_time when updation_time > rm_inserted_at -> updation_time
        _ -> rm_inserted_at
      end

    %{
      post
      | inserted_at: sorting_time,
        updation_time: updation_time
    }
  end

  def structured_post_keys(rp, user_id, post_type_id, post_subtype_id, put_assigned \\ false) do
    post = common_post_keys(rp, user_id, post_type_id, post_subtype_id)

    post =
      %{
        new_match_count: new_match_count_query(user_id, rp.id, post_type_id, post_subtype_id),
        match_count: total_match_count_query(rp.id, post_type_id, post_subtype_id),
        sub_info: create_post_sub_info(rp, post_type_id)
      }
      |> Map.merge(post)

    if put_assigned do
      post |> Map.merge(%{assigned_to_me: rp.assigned_user_id == user_id})
    else
      post
    end
  end

  def add_extra_keys(post, post_type_id, post_subtype_id) do
    cond do
      post_type_id == @post_type_rent_id && post_subtype_id == @post_subtype_property_id ->
        %{
          configuration_type_id: post.configuration_type_id,
          rent_expected: post.rent_expected,
          available_from: post.available_from,
          assigned_owner: get_assigned_owner(post.assigned_owner),
          uploader_type: post.uploader_type || "broker"
        }

      post_type_id == @post_type_rent_id && post_subtype_id == @post_subtype_client_id ->
        %{
          configuration_type_ids: post.configuration_type_ids,
          max_rent: post.max_rent,
          uploader_type: "broker"
        }

      post_type_id == @post_type_resale_id && post_subtype_id == @post_subtype_property_id ->
        {latest_assisted_property_post_agreement_details, is_assisted_property} = ResalePropertyPost.get_latest_assisted_property_post_agreement_details(post, true)

        %{
          is_assisted: is_assisted_property,
          latest_assisted_property_post_agreement_details: latest_assisted_property_post_agreement_details,
          configuration_type_id: post.configuration_type_id,
          price: post.price,
          assigned_owner: get_assigned_owner(post.assigned_owner),
          uploader_type: post.uploader_type || "broker"
        }

      post_type_id == @post_type_resale_id && post_subtype_id == @post_subtype_client_id ->
        %{
          configuration_type_ids: post.configuration_type_ids,
          max_budget: post.max_budget,
          uploader_type: "broker"
        }
    end
  end

  def create_uuid(rp, post_type_id, post_subtype_id) do
    post_type = PostType.get_by_id(post_type_id)
    post_subtype = PostSubType.get_by_id(post_subtype_id)

    (post_type.name |> String.downcase()) <>
      "/" <>
      (post_subtype.name |> String.downcase()) <>
      "/" <>
      rp.uuid
  end

  def create_post_sub_info(rpp, post_type_id) do
    if post_type_id == PostType.resale().id do
      [
        %{
          "text" => "₹ #{format_money(rpp |> Map.get(:price) || rpp |> Map.get(:max_budget))}"
        },
        %{
          "text" => "#{rpp |> Map.get(:parking) || rpp |> Map.get(:min_parking)} parking"
        },
        %{
          "text" => "#{rpp |> Map.get(:carpet_area) || rpp |> Map.get(:min_carpet_area)} Sq ft"
        },
        %{
          "text" => "#{floor_name(rpp |> Map.get(:floor_type_id)) || floor_names(rpp |> Map.get(:floor_type_ids))}"
        }
      ]
    else
      bachelor_text =
        if (rpp |> Map.get(:is_bachelor) || rpp |> Map.get(:is_bachelor_allowed)) in [true, "true"],
          do: "Bachelor",
          else: "Family"

      [
        %{
          "text" => "₹ #{format_money(rpp |> Map.get(:rent_expected) || rpp |> Map.get(:max_rent))}"
        },
        %{
          "text" => "#{bachelor_text}"
        },
        %{
          "text" => "#{furnishing_name(rpp |> Map.get(:furnishing_type_id)) || furnishing_names(rpp |> Map.get(:furnishing_type_ids))}"
        }
      ]
    end
  end

  def create_match_sub_info(rm, rpp, post_type_id) do
    if post_type_id == PostType.resale().id do
      [
        %{
          "text" => "₹ #{format_money(rpp |> Map.get(:price) || rpp |> Map.get(:max_budget))}",
          "perfect_match" => rm.price_ed |> Decimal.to_float() == 0
        },
        %{
          "text" => "#{rpp |> Map.get(:parking) || rpp |> Map.get(:min_parking)} parking",
          "perfect_match" => rm.parking_ed == 0
        },
        %{
          "text" => "#{rpp |> Map.get(:carpet_area) || rpp |> Map.get(:min_carpet_area)} Sq ft",
          "perfect_match" => rm.area_ed |> Decimal.to_float() == 0
        },
        %{
          "text" => "#{floor_name(rpp |> Map.get(:floor_type_id)) || floor_names(rpp |> Map.get(:floor_type_ids))}",
          "perfect_match" => rm.floor_ed == 0
        }
      ]
    else
      bachelor_text = if rpp |> Map.get(:is_bachelor) || rpp |> Map.get(:is_bachelor_allowed), do: "Bachelor", else: "Family"

      [
        %{
          "text" => "₹ #{format_money(rpp |> Map.get(:rent_expected) || rpp |> Map.get(:max_rent))}",
          "perfect_match" => rm.rent_ed |> Decimal.to_float() == 0
        },
        %{
          "text" => "#{bachelor_text}",
          "perfect_match" => rm.bachelor_ed == 0
        },
        %{
          "text" => "#{furnishing_name(rpp |> Map.get(:furnishing_type_id)) || furnishing_names(rpp |> Map.get(:furnishing_type_ids))}",
          "perfect_match" => rm.furnishing_ed == 0
        }
      ]
    end
  end

  def post_title(@post_type_rent_id, @post_subtype_property_id), do: "Rental Property"
  def post_title(@post_type_rent_id, @post_subtype_client_id), do: "Rental Client"
  def post_title(@post_type_resale_id, @post_subtype_property_id), do: "Resale Property"
  def post_title(@post_type_resale_id, @post_subtype_client_id), do: "Resale Client"

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

  def property_info(building_name, configuration_type_id, "Resale") do
    config_name = ConfigurationType.get_by_id(configuration_type_id).name
    "#{config_name} Available For Sale in #{building_name}"
  end

  def property_info(building_name, configuration_type_id, "Rent") do
    config_name = ConfigurationType.get_by_id(configuration_type_id).name
    "#{config_name} Available On Rent in #{building_name}"
  end

  def client_info(building_names, configuration_type_ids, post_type_name)
      when is_nil(building_names) or is_nil(configuration_type_ids) or is_nil(post_type_name),
      do: nil

  def client_info(building_names, configuration_type_ids, _)
      when length(building_names) == 0 or length(configuration_type_ids) == 0,
      do: nil

  def client_info(building_names, configuration_type_ids, post_type_name) do
    config_names =
      configuration_type_ids
      |> Enum.map(&ConfigurationType.get_by_id(&1).name)
      |> Enum.join("/")
      |> String.replace(" BHK", "")
      |> return_config_name

    building_names = Enum.join(building_names, " / ")

    client_info_string(building_names, config_names, post_type_name)
  end

  def client_info_string(building_names, config_names, "Rent") do
    "Required #{config_names} On Rent in #{building_names}"
  end

  def client_info_string(building_names, config_names, "Resale") do
    "Required #{config_names} in #{building_names}"
  end

  def return_config_name(names) when names == "Studio / 1 RK", do: "Studio / 1 RK"
  def return_config_name(names), do: names |> Kernel.<>(" BHK")

  defp floor_name(floor_type_id) when is_nil(floor_type_id), do: nil
  defp floor_name(floor_type_id) when is_binary(floor_type_id), do: floor_name(floor_type_id |> String.to_integer())

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

  defp furnishing_name(furnishing_type_id) when is_binary(furnishing_type_id),
    do: furnishing_name(furnishing_type_id |> String.to_integer())

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

  defmacro is_post_rent_property(post_type_id, post_subtype_id) do
    quote do: unquote(post_type_id) == @post_type_rent_id and unquote(post_subtype_id) == @post_subtype_property_id
  end

  defmacro is_post_rent_client(post_type_id, post_subtype_id) do
    quote do: unquote(post_type_id) == @post_type_rent_id and unquote(post_subtype_id) == @post_subtype_client_id
  end

  defmacro is_post_resale_property(post_type_id, post_subtype_id) do
    quote do: unquote(post_type_id) == @post_type_resale_id and unquote(post_subtype_id) == @post_subtype_property_id
  end

  defmacro is_post_resale_client(post_type_id, post_subtype_id) do
    quote do: unquote(post_type_id) == @post_type_resale_id and unquote(post_subtype_id) == @post_subtype_client_id
  end

  def filter_marked_matches(query) do
    query
    |> where(
      [rm],
      rm.is_relevant == true and
        rm.already_contacted == false and
        is_nil(rm.outgoing_call_log_id) and
        rm.blocked == false
    )
  end

  def total_match_count_query(rid, post_type_id, post_subtype_id)
      when is_post_rent_property(post_type_id, post_subtype_id) do
    RentalMatch.rental_match_base_query()
    |> filter_marked_matches()
    |> where([rm], rm.rental_property_id == ^rid)
    |> Repo.aggregate(:count, :id)
  end

  def total_match_count_query(rid, post_type_id, post_subtype_id)
      when is_post_rent_client(post_type_id, post_subtype_id) do
    RentalMatch.rental_match_base_query()
    |> filter_marked_matches()
    |> where([rm], rm.rental_client_id == ^rid)
    |> Repo.aggregate(:count, :id)
  end

  def total_match_count_query(rid, post_type_id, post_subtype_id)
      when is_post_resale_property(post_type_id, post_subtype_id) do
    ResaleMatch.resale_match_base_query()
    |> filter_marked_matches()
    |> where([rm], rm.resale_property_id == ^rid)
    |> Repo.aggregate(:count, :id)
  end

  def total_match_count_query(rid, post_type_id, post_subtype_id)
      when is_post_resale_client(post_type_id, post_subtype_id) do
    ResaleMatch.resale_match_base_query()
    |> filter_marked_matches()
    |> where([rm], rm.resale_client_id == ^rid)
    |> Repo.aggregate(:count, :id)
  end

  def new_match_count_query(user_id, rid, post_type_id, post_subtype_id)
      when is_post_rent_property(post_type_id, post_subtype_id) do
    RentalMatch.rental_match_base_query()
    |> join(:left, [rm], mrs in MatchReadStatus,
      on:
        rm.id == mrs.rental_matches_id and
          mrs.user_id == ^user_id
    )
    |> filter_marked_matches()
    |> where([rm, rpp, rcp, mrs], rm.rental_property_id == ^rid and is_nil(mrs.id))
    |> Repo.aggregate(:count, :id)
  end

  def new_match_count_query(user_id, rid, post_type_id, post_subtype_id)
      when is_post_rent_client(post_type_id, post_subtype_id) do
    RentalMatch.rental_match_base_query()
    |> join(:left, [rm], mrs in MatchReadStatus,
      on:
        rm.id == mrs.rental_matches_id and
          mrs.user_id == ^user_id
    )
    |> filter_marked_matches()
    |> where([rm, rpp, rcp, mrs], rm.rental_client_id == ^rid and is_nil(mrs.id))
    |> Repo.aggregate(:count, :id)
  end

  def new_match_count_query(user_id, rid, post_type_id, post_subtype_id)
      when is_post_resale_property(post_type_id, post_subtype_id) do
    ResaleMatch.resale_match_base_query()
    |> join(:left, [rm], mrs in MatchReadStatus,
      on:
        rm.id == mrs.resale_matches_id and
          mrs.user_id == ^user_id
    )
    |> filter_marked_matches()
    |> where([rm, rpp, rcp, mrs], rm.resale_property_id == ^rid and is_nil(mrs.id))
    |> Repo.aggregate(:count, :id)
  end

  def new_match_count_query(user_id, rid, post_type_id, post_subtype_id)
      when is_post_resale_client(post_type_id, post_subtype_id) do
    ResaleMatch.resale_match_base_query()
    |> join(:left, [rm], mrs in MatchReadStatus,
      on:
        rm.id == mrs.resale_matches_id and
          mrs.user_id == ^user_id
    )
    |> filter_marked_matches()
    |> where([rm, rpp, rcp, mrs], rm.resale_client_id == ^rid and is_nil(mrs.id))
    |> Repo.aggregate(:count, :id)
  end

  def get_only_matching_building_names(user_id, rcp, post_type_id, rm) do
    building_ids = rcp.building_ids

    cred = Repo.get!(Credential, user_id)
    organization_id = cred.organization_id

    org_user_ids =
      Credential
      |> where(organization_id: ^organization_id)
      |> select([c], c.id)
      |> Repo.all()

    if(Enum.member?(org_user_ids, rcp.assigned_user_id) or is_nil(rm)) do
      Building
      |> where([b], b.id in ^building_ids)
      |> distinct(true)
      |> select([b], b.name)
      |> Repo.all()
    else
      property_post = if post_type_id == @post_type_rent_id, do: rm.rental_property, else: rm.resale_property

      Building
      |> where([b], b.id == ^property_post.building_id)
      |> select([b], b.name)
      |> Repo.all()
    end
  end

  def get_only_matching_config_ids(user_id, rcp, post_type_id, rm) do
    configuration_type_ids = rcp.configuration_type_ids

    cred = Repo.get!(Credential, user_id)
    organization_id = cred.organization_id

    org_user_ids =
      Credential
      |> where(organization_id: ^organization_id)
      |> select([c], c.id)
      |> Repo.all()

    if(Enum.member?(org_user_ids, rcp.assigned_user_id) or is_nil(rm)) do
      configuration_type_ids
    else
      property_post = if post_type_id == @post_type_rent_id, do: rm.rental_property, else: rm.resale_property
      handle_matching_configs(configuration_type_ids, [property_post.configuration_type_id])
    end
  end

  def handle_matching_configs(client_configuration_type_ids, property_configuration_type_ids) do
    matched_configs = client_configuration_type_ids -- client_configuration_type_ids -- property_configuration_type_ids
    # handle cases of 0.5 config matches
    if matched_configs == [], do: client_configuration_type_ids, else: matched_configs
  end

  def broker_ids_for_client_query(query, page, per_page) do
    total_broker_query =
      query
      |> select([rm, rcp, rpp], rcp.assigned_user_id)
      |> distinct(true)

    broker_ids_common_query(total_broker_query, page, per_page)
  end

  def broker_ids_for_property_query(query, page, per_page) do
    total_broker_query =
      query
      |> select([rm, rcp, rpp], rpp.assigned_user_id)
      |> distinct(true)

    broker_ids_common_query(total_broker_query, page, per_page)
  end

  def broker_ids_common_query(total_broker_query, page, per_page) do
    total_broker_ids = total_broker_query |> Repo.all()

    paginated_broker_ids =
      total_broker_query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    {total_broker_ids, paginated_broker_ids}
  end

  def rental_client_call_log_time(rental_client_id) do
    RentalMatch
    |> join(:inner, [rm], cl in CallLog, on: cl.id == rm.outgoing_call_log_id)
    |> where(
      [rm, cl],
      rm.rental_client_id == ^rental_client_id and
        not is_nil(rm.outgoing_call_log_id) and
        rm.is_relevant == true
    )
    |> limit(1)
    |> select([_, cl], fragment("ROUND(extract(epoch from ?))", cl.start_time))
    |> Repo.one()
  end

  def rental_property_call_log_time(rental_property_id) do
    RentalMatch
    |> join(:inner, [rm], cl in CallLog, on: cl.id == rm.outgoing_call_log_id)
    |> where(
      [rm, cl],
      rm.rental_property_id == ^rental_property_id and
        not is_nil(rm.outgoing_call_log_id) and
        rm.is_relevant == true
    )
    |> limit(1)
    |> select([_, cl], fragment("ROUND(extract(epoch from ?))", cl.start_time))
    |> Repo.one()
  end

  def resale_client_call_log_time(resale_client_id) do
    ResaleMatch
    |> join(:inner, [rm], cl in CallLog, on: cl.id == rm.outgoing_call_log_id)
    |> where(
      [rm, cl],
      rm.resale_client_id == ^resale_client_id and
        not is_nil(rm.outgoing_call_log_id) and
        rm.is_relevant == true
    )
    |> limit(1)
    |> select([_, cl], fragment("ROUND(extract(epoch from ?))", cl.start_time))
    |> Repo.one()
  end

  def resale_property_call_log_time(resale_property_id) do
    ResaleMatch
    |> join(:inner, [rm], cl in CallLog, on: cl.id == rm.outgoing_call_log_id)
    |> where(
      [rm, cl],
      rm.resale_property_id == ^resale_property_id and
        not is_nil(rm.outgoing_call_log_id) and
        rm.is_relevant == true
    )
    |> limit(1)
    |> select([_, cl], fragment("ROUND(extract(epoch from ?))", cl.start_time))
    |> Repo.one()
  end

  def rental_property_is_read(rental_property_id, user_id) do
    count = new_match_count_query(user_id, rental_property_id, @post_type_rent_id, @post_subtype_property_id)
    count == 0
  end

  def rental_client_is_read(rental_client_id, user_id) do
    count = new_match_count_query(user_id, rental_client_id, @post_type_rent_id, @post_subtype_client_id)
    count == 0
  end

  def resale_property_is_read(resale_property_id, user_id) do
    count = new_match_count_query(user_id, resale_property_id, @post_type_resale_id, @post_subtype_property_id)
    count == 0
  end

  def resale_client_is_read(resale_client_id, user_id) do
    count = new_match_count_query(user_id, resale_client_id, @post_type_resale_id, @post_subtype_client_id)
    count == 0
  end

  def mark_older_posts_as_unread(user_id, post_id, "rent", "client") do
    match_read_ids =
      RentalMatch.rental_match_base_query()
      |> join(:left, [rm], mrs in MatchReadStatus,
        on:
          rm.id == mrs.rental_matches_id and
            mrs.user_id == ^user_id
      )
      |> filter_marked_matches()
      |> where([rm, rpp, rcp, mrs], rm.rental_client_id == ^post_id)
      |> select([rm, rpp, rcp, mrs], mrs.id)
      |> Repo.all()

    MatchReadStatus |> where([mrs], mrs.id in ^match_read_ids) |> Repo.delete_all()
  end

  def mark_older_posts_as_unread(user_id, post_id, "rent", "property") do
    match_read_ids =
      RentalMatch.rental_match_base_query()
      |> join(:left, [rm], mrs in MatchReadStatus,
        on:
          rm.id == mrs.rental_matches_id and
            mrs.user_id == ^user_id
      )
      |> filter_marked_matches()
      |> where([rm, rpp, rcp, mrs], rm.rental_property_id == ^post_id)
      |> select([rm, rpp, rcp, mrs], mrs.id)
      |> Repo.all()

    MatchReadStatus |> where([mrs], mrs.id in ^match_read_ids) |> Repo.delete_all()
  end

  def mark_older_posts_as_unread(user_id, post_id, "resale", "client") do
    match_read_ids =
      ResaleMatch.resale_match_base_query()
      |> join(:left, [rm], mrs in MatchReadStatus,
        on:
          rm.id == mrs.resale_matches_id and
            mrs.user_id == ^user_id
      )
      |> filter_marked_matches()
      |> where([rm, rpp, rcp, mrs], rm.resale_client_id == ^post_id)
      |> select([rm, rpp, rcp, mrs], mrs.id)
      |> Repo.all()

    MatchReadStatus |> where([mrs], mrs.id in ^match_read_ids) |> Repo.delete_all()
  end

  def mark_older_posts_as_unread(user_id, post_id, "resale", "property") do
    match_read_ids =
      ResaleMatch.resale_match_base_query()
      |> join(:left, [rm], mrs in MatchReadStatus,
        on:
          rm.id == mrs.resale_matches_id and
            mrs.user_id == ^user_id
      )
      |> filter_marked_matches()
      |> where([rm, rpp, rcp, mrs], rm.resale_property_id == ^post_id)
      |> select([rm, rpp, rcp, mrs], mrs.id)
      |> Repo.all()

    MatchReadStatus |> where([mrs], mrs.id in ^match_read_ids) |> Repo.delete_all()
  end

  def mark_older_owner_posts_as_unread(post_id, "rent", "property") do
    match_read_ids =
      RentalMatch.rental_match_base_query()
      |> join(:left, [rm], mrs in MatchReadStatus, on: rm.id == mrs.rental_matches_id)
      |> filter_marked_matches()
      |> where([rm, rpp, rcp, mrs], rm.rental_property_id == ^post_id)
      |> select([rm, rpp, rcp, mrs], mrs.id)
      |> Repo.all()

    MatchReadStatus |> where([mrs], mrs.id in ^match_read_ids) |> Repo.delete_all()
  end

  def mark_older_owner_posts_as_unread(post_id, "resale", "property") do
    match_read_ids =
      ResaleMatch.resale_match_base_query()
      |> join(:left, [rm], mrs in MatchReadStatus, on: rm.id == mrs.resale_matches_id)
      |> filter_marked_matches()
      |> where([rm, rpp, rcp, mrs], rm.resale_property_id == ^post_id)
      |> select([rm, rpp, rcp, mrs], mrs.id)
      |> Repo.all()

    MatchReadStatus |> where([mrs], mrs.id in ^match_read_ids) |> Repo.delete_all()
  end

  def rental_weight_vector() do
    @rental_weight_vector
  end

  def resale_weight_vector() do
    @resale_weight_vector
  end

  def rental_edit_distance_vector(res) do
    [res.rent_ed, res.bachelor_ed, res.furnishing_ed]
  end

  def resale_edit_distance_vector(res) do
    [res.price_ed, res.area_ed, res.parking_ed, res.floor_ed]
  end

  def fetch_owner_matches(params) do
    if params["match_type"] == "resale" do
      params |> ResaleMatch.fetch_owner_matches()
    else
      params |> RentalMatch.fetch_owner_matches()
    end
  end

  def fetch_all_matches(params) do
    if params["match_type"] == "resale" do
      params |> ResaleMatch.fetch_all_matches()
    else
      params |> RentalMatch.fetch_all_matches()
    end
  end

  @doc """
  Dot product of two vector
  """
  def dotproduct([], []), do: 0
  def dotproduct([ah | at] = _a, [bh | bt] = _b) when is_number(ah) and is_number(bh), do: ah * bh + dotproduct(at, bt)

  def dotproduct([ah | at] = _a, [bh | bt] = _b) when not is_number(ah),
    do: (ah |> Decimal.to_float()) * bh + dotproduct(at, bt)

  def dotproduct([ah | at] = _a, [bh | bt] = _b) when not is_number(bh),
    do: (bh |> Decimal.to_float()) * ah + dotproduct(at, bt)
end
