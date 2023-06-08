defmodule BnApis.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.{
    Buildings,
    Accounts,
    Organizations,
    CallLogs,
    ProcessPostMatchWorker,
    Log
  }

  alias BnApis.Orders.MatchPlus
  alias BnApis.Memberships.MatchPlusMembership
  alias BnApis.Accounts.{Credential, EmployeeRole, Owner}
  alias BnApis.Helpers.WhatsappHelper

  alias BnApis.Posts.{
    ConfigurationType,
    FurnishingType,
    FloorType,
    PostType,
    PostSubType,
    ProjectType
  }

  alias BnApis.Posts.{
    RentalClientPost,
    RentalPropertyPost,
    ResaleClientPost,
    ResalePropertyPost
  }

  alias BnApis.Posts.{
    ReportedRentalClientPost,
    ReportedRentalPropertyPost,
    ReportedResaleClientPost,
    ReportedResalePropertyPost,
    ContactedRentalPropertyPost,
    ContactedResalePropertyPost
  }

  alias BnApis.Helpers.Time

  alias BnApis.Posts.{RentalMatch, ResaleMatch, PostAssignmentHistory, RawPosts}
  alias BnApis.CallLogs.CallLogCallStatus
  alias BnApis.Organizations.{BrokerRole, BrokerType, Broker}
  alias BnApis.Accounts.BlockedUser
  alias BnApis.Buildings.Building
  alias BnApis.Places.Polygon
  alias BnApis.Homeloan.LeadType
  alias BnApis.Reasons.{Reason, ReasonType}
  alias BnApis.Homeloan.Bank
  alias BnApis.Homeloan.Status
  alias BnApis.Homeloan.Lead
  alias BnApis.Organizations.BrokerCommission

  # in days
  @grace_period 2

  @post_per_page 10
  @broker_per_page 10
  @expiring_post_per_page 100

  @temp_post_per_page 100

  @matches_per_broker 5
  @matches_per_post 5

  @property_sold_out_reason_id 13

  # Uploader types
  @owner "owner"
  @broker "broker"

  # Post types
  @rent "rent"
  @resale "resale"

  # Post and it's attributes
  @rent_map %{
    :type => @rent,
    :table => "rental_property_posts",
    :verify_mssg_template => "rental_button_verified_msg",
    :expiry_mssg_template => "rental_button_msg",
    :archive_auto_reply_mssg_template => "auto_reply_no",
    :refresh_auto_reply_mssg_template => "auto_reply_yes",
    :expiry_reminder_mssg_template => "reminder_rental_button",
    :referral_mssg_template => "referral_message",
    :module => RentalPropertyPost,
    :contacted_module => ContactedRentalPropertyPost
  }

  @resale_map %{
    :type => @resale,
    :table => "resale_property_posts",
    :verify_mssg_template => "resale_button_verified_msg",
    :expiry_mssg_template => "resale_button_msg",
    :archive_auto_reply_mssg_template => "auto_reply_no",
    :refresh_auto_reply_mssg_template => "auto_reply_yes",
    :expiry_reminder_mssg_template => "reminder_resale_button",
    :referral_mssg_template => "referral_message",
    :module => ResalePropertyPost,
    :contacted_module => ContactedResalePropertyPost
  }

  @restriction_limit_for_post_contact_per_day 29
  @warning_limit_for_post_contact_per_day 24
  @restriction_limit_for_unverified_property_per_day_by_owner 10

  def post_map(@rent), do: @rent_map
  def post_map(@resale), do: @resale_map

  def expiry_mssg_template(@rent), do: @rent_map.expiry_mssg_template
  def expiry_mssg_template(@resale), do: @resale_map.expiry_mssg_template

  def expiry_reminder_mssg_template(@rent), do: @rent_map.expiry_reminder_mssg_template
  def expiry_reminder_mssg_template(@resale), do: @resale_map.expiry_reminder_mssg_template

  def rent(), do: @rent
  def resale(), do: @resale

  def restriction_limit_for_post_contact_per_day(), do: @restriction_limit_for_post_contact_per_day
  def warning_limit_for_post_contact_per_day(), do: @warning_limit_for_post_contact_per_day
  def restriction_limit_for_unverified_property_per_day_by_owner(), do: @restriction_limit_for_unverified_property_per_day_by_owner

  @doc """
  In Days
  """
  @expiry_days_map %{
    PostType.rent().name => %{
      "client" => %{
        ConfigurationType.studio().name => 15,
        ConfigurationType.bhk_1().name => 15,
        ConfigurationType.bhk_1_5().name => 15,
        ConfigurationType.bhk_2().name => 15,
        ConfigurationType.bhk_2_5().name => 15,
        ConfigurationType.bhk_3().name => 15,
        ConfigurationType.bhk_3_5().name => 15,
        ConfigurationType.bhk_4().name => 15,
        ConfigurationType.bhk_4_plus().name => 15
      },
      "property" => %{
        ConfigurationType.studio().name => 15,
        ConfigurationType.bhk_1().name => 15,
        ConfigurationType.bhk_1_5().name => 15,
        ConfigurationType.bhk_2().name => 15,
        ConfigurationType.bhk_2_5().name => 15,
        ConfigurationType.bhk_3().name => 15,
        ConfigurationType.bhk_3_5().name => 15,
        ConfigurationType.bhk_4().name => 15,
        ConfigurationType.bhk_4_plus().name => 15
      }
    },
    PostType.resale().name => %{
      "client" => %{
        ConfigurationType.studio().name => 30,
        ConfigurationType.bhk_1().name => 30,
        ConfigurationType.bhk_1_5().name => 30,
        ConfigurationType.bhk_2().name => 30,
        ConfigurationType.bhk_2_5().name => 30,
        ConfigurationType.bhk_3().name => 30,
        ConfigurationType.bhk_3_5().name => 30,
        ConfigurationType.bhk_4().name => 30,
        ConfigurationType.bhk_4_plus().name => 30
      },
      "property" => %{
        ConfigurationType.studio().name => 30,
        ConfigurationType.bhk_1().name => 30,
        ConfigurationType.bhk_1_5().name => 30,
        ConfigurationType.bhk_2().name => 30,
        ConfigurationType.bhk_2_5().name => 30,
        ConfigurationType.bhk_3().name => 30,
        ConfigurationType.bhk_3_5().name => 30,
        ConfigurationType.bhk_4().name => 30,
        ConfigurationType.bhk_4_plus().name => 30
      }
    }
  }

  @sorting_params [
    %{id: 1, name: "Added on", key: "added_on"},
    %{id: 2, name: "Price", key: "price"}
  ]

  def expiry_days_map, do: @expiry_days_map

  def get_phone_number_with_country_code(phone_number) do
    phone_number
    |> String.replace(~s("), "")
    |> append_country_code()
  end

  defp append_country_code(phone = "+91" <> _), do: phone
  defp append_country_code(phone), do: "+91" <> phone

  defp get_uploader_id(%{
         "uploader_type" => @owner,
         "employees_credentials_id" => id
       }),
       do: id

  defp get_uploader_id(%{"user_id" => id}), do: id

  defp add_verified_credentials(params = %{"is_verified" => true}) do
    params
    |> Map.put("updation_time", NaiveDateTime.utc_now())
    |> Map.put("last_verified_at", NaiveDateTime.utc_now())
    |> Map.put("verified_by_employees_credentials_id", params["employees_credentials_id"])
  end

  defp add_verified_credentials(params), do: params

  defp add_edited_credentials(params) do
    params
    |> Map.put("updation_time", NaiveDateTime.utc_now())
    |> Map.put("last_edited_at", NaiveDateTime.utc_now())
    |> Map.put("edited_by_employees_credentials_id", params["employee_cred_id"])
  end

  defp maybe_add_edited_owner(params) do
    case params["owner_name"] do
      nil ->
        params

      name ->
        params
        |> Map.put("assigned_owner", %{"name" => name})
    end
  end

  defp add_uploader_type(
         params = %{
           "uploader_type" => @owner
         }
       ) do
    {:ok, owner} = Owner.create_or_get_owner(params)
    Map.put(params, "assigned_owner_id", owner.id)
  end

  defp add_uploader_type(params),
    do: Map.put(params, "uploader_type", @broker)

  defp parse_available_from(%{"available_from" => date_unix} = params) do
    datetime = to_date_time(date_unix)
    Map.put(params, "available_from", datetime)
  end

  defp parse_available_from(params), do: params

  defp to_date_time(unix) when is_binary(unix),
    do:
      unix
      |> String.to_integer()
      |> to_date_time()

  defp to_date_time(unix) do
    {:ok, datetime} = DateTime.from_unix(unix)
    datetime
  end

  defp send_verified_whatsapp_message(post, changeset_changes, uploader_id, uploader_type, _post_map = @rent_map),
    do:
      send_verified_whatsapp_message(
        post,
        changeset_changes,
        [:building, :configuration_type, :furnishing_type, :assigned_owner],
        uploader_id,
        uploader_type,
        @rent_map
      )

  defp send_verified_whatsapp_message(post, changeset_changes, uploader_id, uploader_type, _post_map = @resale_map),
    do:
      send_verified_whatsapp_message(
        post,
        changeset_changes,
        [:building, :configuration_type, :assigned_owner],
        uploader_id,
        uploader_type,
        @resale_map
      )

  defp send_verified_whatsapp_message(post, changeset_changes, associations, uploader_id, uploader_type, post_map) do
    case Repo.get_by(post_map.module, uuid: post.uuid) do
      nil ->
        {:error, "Post not found!"}

      post ->
        post = post |> Repo.preload(associations)

        if post.is_verified and not is_nil(post.assigned_owner) and not is_nil(post.assigned_owner.phone_number) do
          owner_phone_number = post.assigned_owner.phone_number |> get_phone_number_with_country_code()

          Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
            owner_phone_number,
            post_map.verify_mssg_template,
            get_post_details_for_whatsapp_message(post, post_map.type),
            %{"entity_type" => post_map.table, "entity_id" => post.id}
          ])

          Log.log(post.id, "rental_property_posts", uploader_id, uploader_type, changeset_changes)
          {:ok, post}
        else
          {:ok, post}
        end
    end
  end

  def fetch_form_data(logged_in_user) do
    broker_id = logged_in_user.broker_id
    loan_types = BrokerCommission.get_loan_types(broker_id) |> BrokerCommission.maybe_append_other_loan_type(broker_id)
    loan_types_list = Bank.loan_type_list()

    %{
      post_types: PostType.seed_data(),
      post_sub_types: PostSubType.seed_data(),
      configuration_types: ConfigurationType.seed_data(),
      project_types: ProjectType.seed_data(),
      furnishing_types: FurnishingType.seed_data(),
      floor_types: FloorType.seed_data(),
      call_statuses: CallLogCallStatus.seed_data(),
      team_data: Organizations.get_team_members(logged_in_user),
      employment_type: LeadType.employment_type_list(),
      day_range_filters: Time.get_owners_day_range_filters(),
      dsa_date_range_filters: Time.get_dsa_date_filters(),
      post_sorting_params: @sorting_params,
      delete_bucket_reason: Reason.seed_data() |> Enum.filter(&(&1.reason_type_id == ReasonType.delete_bucket().id)),
      bank_list: Bank.get_all_bank_data(),
      dsa_status_list: Status.dsa_status_list(),
      loan_types: loan_types,
      property_types: Lead.property_types(),
      property_stages: Lead.property_stages(),
      loan_types_list: loan_types_list,
      hl_lead_status_filters: Status.lead_status_filters_list()
    }
  end

  def fetch_admin_form_data(_logged_in_user) do
    %{
      configuration_types: ConfigurationType.seed_data(),
      furnishing_types: FurnishingType.seed_data(),
      floor_types: FloorType.seed_data(),
      broker_types: BrokerType.seed_data(),
      employee_roles: EmployeeRole.seed_data(),
      raw_posts_junk_reasons: RawPosts.junk_reasons(),
      raw_posts_unanswered_reasons: RawPosts.unanswered_reasons()
    }
  end

  def create_rental_client(params) do
    case Buildings.get_building_data_from_ids(params["building_ids"]) do
      {:ok, buildings} ->
        expiry_days = get_expiry_days("rent", "client", buildings, params)
        expires_in = expiry_days |> Time.set_expiry_time()
        building_ids = buildings |> Enum.map(& &1[:building_id])

        params =
          params
          |> Map.merge(%{
            "building_ids" => building_ids,
            "expires_in" => expires_in
          })

        changeset = RentalClientPost.changeset(%RentalClientPost{}, params)
        changeset |> Repo.insert()

      {:error, message} ->
        {:error, message}
    end
  end

  def create_rental_property(params) do
    case Buildings.get_building_data_from_ids([params["building_id"]]) do
      {:ok, buildings} ->
        expiry_days = get_expiry_days("rent", "property", buildings, params)
        expires_in = expiry_days |> Time.set_expiry_time()

        params
        |> add_uploader_type()
        |> parse_available_from()
        |> add_verified_credentials()
        |> Map.merge(%{
          "building_id" => hd(buildings)[:building_id],
          "expires_in" => expires_in
        })
        |> RentalPropertyPost.new()
        |> case do
          {:ok, changeset} ->
            uploader_id = get_uploader_id(params)

            changeset
            |> Repo.insert!()
            |> send_verified_whatsapp_message(changeset.changes, uploader_id, params["uploader_type"], @rent_map)

          {:error, _reason} = error ->
            error
        end

      {:error, _message} = error ->
        error
    end
  end

  def create_resale_client(params) do
    case Buildings.get_building_data_from_ids(params["building_ids"]) do
      {:ok, buildings} ->
        expiry_days = get_expiry_days("resale", "client", buildings, params)
        expires_in = expiry_days |> Time.set_expiry_time()
        building_ids = buildings |> Enum.map(& &1[:building_id])

        params =
          params
          |> Map.merge(%{
            "building_ids" => building_ids,
            "expires_in" => expires_in
          })

        changeset = ResaleClientPost.changeset(%ResaleClientPost{}, params)
        changeset |> Repo.insert()

      {:error, message} ->
        {:error, message}
    end
  end

  def create_resale_property(params) do
    case Buildings.get_building_data_from_ids([params["building_id"]]) do
      {:ok, buildings} ->
        expiry_days = get_expiry_days("resale", "property", buildings, params)
        expires_in = expiry_days |> Time.set_expiry_time()

        params
        |> add_uploader_type()
        |> add_verified_credentials()
        |> Map.merge(%{
          "building_id" => hd(buildings)[:building_id],
          "expires_in" => expires_in
        })
        |> ResalePropertyPost.new()
        |> case do
          {:ok, changeset} ->
            uploader_id = get_uploader_id(params)

            changeset
            |> Repo.insert!()
            |> send_verified_whatsapp_message(changeset.changes, uploader_id, params["uploader_type"], @resale_map)

          {:error, _reason} = error ->
            error
        end

      {:error, message} ->
        {:error, message}
    end
  end

  def get_total_owner_posts(city_id \\ nil) do
    {_, total_count} = Cachex.get(:bn_apis_cache, "owner_posts_total_count_#{city_id}")

    if is_nil(total_count) do
      {_, rental_total_count, _, _} = RentalPropertyPost.fetch_rental_posts(%{"city_id" => city_id}, nil, true, true)
      {_, resale_total_count, _, _} = ResalePropertyPost.fetch_resale_posts(%{"city_id" => city_id}, nil, true, true)
      owner_posts_total_count = (rental_total_count + resale_total_count) |> Integer.to_string()
      Cachex.put(:bn_apis_cache, "owner_posts_total_count_#{city_id}", owner_posts_total_count)
      owner_posts_total_count
    else
      total_count
    end
  end

  def get_expiry_days(post_type, post_sub_type, buildings, params)
      when post_sub_type == "property" do
    expiry_column = post_type |> get_expiry_column()

    expiry =
      (buildings
       |> hd())[expiry_column][post_sub_type][
        ConfigurationType.get_by_id(params["configuration_type_id"]).name
      ]

    if is_nil(expiry) do
      post_type |> get_default_expiry()
    else
      expiry
    end
  end

  def get_expiry_days(post_type, post_sub_type, buildings, params) do
    expiry_column = post_type |> get_expiry_column()
    configuration_type_ids = params["configuration_type_ids"]

    expiry =
      buildings
      |> Enum.map(fn building ->
        Enum.map(
          configuration_type_ids,
          &building[expiry_column][post_sub_type][
            ConfigurationType.get_by_id(&1).name
          ]
        )
        |> Enum.max()
      end)
      |> Enum.max()

    if is_nil(expiry) do
      post_type |> get_default_expiry()
    else
      expiry
    end
  end

  def get_default_expiry(post_type) do
    case post_type do
      "rent" -> 15
      _ -> 30
    end
  end

  def get_expiry_column(post_type) do
    case post_type do
      "rent" -> :rent_config_expiry
      _ -> :resale_config_expiry
    end
  end

  def post_per_page, do: @post_per_page
  def broker_per_page, do: @broker_per_page
  def matches_per_broker, do: @matches_per_broker
  def matches_per_post, do: @matches_per_post
  def grace_period, do: @grace_period * 24 * 60 * 60

  def fetch_posts(user_id) do
    RentalClientPost.fetch_posts(user_id) ++
      RentalPropertyPost.fetch_posts(user_id) ++
      ResaleClientPost.fetch_posts(user_id) ++
      ResalePropertyPost.fetch_posts(user_id)
  end

  def fetch_org_user_rental_client_posts(organization_id, user_id) do
    RentalClientPost.fetch_org_user_posts(organization_id, user_id)
  end

  def fetch_org_user_rental_property_posts(organization_id, user_id) do
    RentalPropertyPost.fetch_org_user_posts(organization_id, user_id)
  end

  def fetch_org_user_resale_client_posts(organization_id, user_id) do
    ResaleClientPost.fetch_org_user_posts(organization_id, user_id)
  end

  def fetch_org_user_resale_property_posts(organization_id, user_id) do
    ResalePropertyPost.fetch_org_user_posts(organization_id, user_id)
  end

  def fetch_org_user_rental_posts(organization_id, user_id) do
    fetch_org_user_rental_client_posts(organization_id, user_id) ++
      fetch_org_user_rental_property_posts(organization_id, user_id)
  end

  def fetch_org_user_resale_posts(organization_id, user_id) do
    fetch_org_user_resale_client_posts(organization_id, user_id) ++
      fetch_org_user_resale_property_posts(organization_id, user_id)
  end

  def segregate_active_inactive_posts(posts) do
    posts
    |> Enum.split_with(&active_posts_check(&1))
  end

  def active_posts_check(post) do
    post.archived == false &&
      NaiveDateTime.compare(post.expires_in, NaiveDateTime.utc_now()) in [
        :eq,
        :gt
      ]
  end

  def fetch_all_posts(organization_id, user_id, page) do
    posts =
      RentalClientPost.fetch_all_posts(organization_id, user_id) ++
        RentalPropertyPost.fetch_all_posts(organization_id, user_id) ++
        ResaleClientPost.fetch_all_posts(organization_id, user_id) ++
        ResalePropertyPost.fetch_all_posts(organization_id, user_id)

    total_posts = posts |> length

    posts =
      posts
      |> Enum.sort_by(
        fn post ->
          {post.assigned_to_me, post.updation_time || post.inserted_at}
        end,
        &>=/2
      )
      |> Enum.slice(((page - 1) * @post_per_page)..(page * @post_per_page - 1))
      |> Enum.group_by(& &1.assigned_to_me)

    assigned_to_me_posts =
      (posts[true] || [])
      |> Enum.map(fn post -> post |> Map.delete(:assigned_to_me) end)

    assigned_to_others_posts =
      (posts[false] || [])
      |> Enum.map(fn post -> post |> Map.delete(:assigned_to_me) end)

    has_more_posts = page < Float.ceil(total_posts / @post_per_page)

    {:ok, assigned_to_me_posts, assigned_to_others_posts, has_more_posts}
  end

  def team_posts(organization_id, user_id, page) do
    posts =
      RentalClientPost.team_posts(organization_id, user_id) ++
        RentalPropertyPost.team_posts(organization_id, user_id) ++
        ResaleClientPost.team_posts(organization_id, user_id) ++
        ResalePropertyPost.team_posts(organization_id, user_id)

    total_posts = posts |> length

    posts =
      posts
      |> Enum.sort_by(
        fn post ->
          {post.assigned_to_me, post.updation_time || post.inserted_at}
        end,
        &>=/2
      )
      |> Enum.slice(((page - 1) * @post_per_page)..(page * @post_per_page - 1))

    has_more_posts = page < Float.ceil(total_posts / @post_per_page)

    {:ok, posts, has_more_posts}
  end

  def fetch_all_property_posts(params, broker \\ nil, is_owner \\ nil) do
    {posts, total_count, has_more_posts, expiry_wise_count} =
      if params["post_type"] == "resale" do
        params |> ResalePropertyPost.fetch_resale_posts(broker, is_owner)
      else
        params |> RentalPropertyPost.fetch_rental_posts(broker, is_owner)
      end

    if not is_nil(broker) do
      posts = if params["post_type"] == "resale", do: hide_owner_info_for_assisted_posts(posts), else: posts
      {posts, total_count, has_more_posts, expiry_wise_count}
    else
      # for admin apis
      owner_uuids = posts |> Enum.map(& &1.assigned_owner.uuid)
      owner_phone_numbers = posts |> Enum.map(& &1.assigned_owner.phone_number)
      post_ids = posts |> Enum.map(& &1.id)

      broker_phone_map =
        Credential
        |> where([c], c.phone_number in ^owner_phone_numbers and c.active == true)
        |> Repo.all()
        |> Enum.reduce(%{}, fn data, acc -> Map.put(acc, data.phone_number, true) end)

      matches_count_map =
        if params["post_type"] == "resale" do
          ResaleMatch
          |> where([rm], rm.resale_property_id in ^post_ids)
          |> Repo.all()
          |> Enum.reduce(%{}, fn data, acc ->
            Map.put(acc, data.resale_property_id, %{
              "count" => (acc[data.resale_property_id]["count"] || 0) + 1,
              "contacted_count" =>
                (acc[data.resale_property_id]["contacted_count"] || 0) +
                  if(data.already_contacted == true, do: 1, else: 0)
            })
          end)
        else
          RentalMatch
          |> where([rm], rm.rental_property_id in ^post_ids)
          |> Repo.all()
          |> Enum.reduce(%{}, fn data, acc ->
            Map.put(acc, data.rental_property_id, %{
              "count" => (acc[data.rental_property_id]["count"] || 0) + 1,
              "contacted_count" =>
                (acc[data.rental_property_id]["contacted_count"] || 0) +
                  if(data.already_contacted == true, do: 1, else: 0)
            })
          end)
        end

      resale_owner_wise_count =
        ResalePropertyPost
        |> join(:inner, [r], o in Owner, on: o.id == r.assigned_owner_id)
        |> where([r, o], o.uuid in ^owner_uuids and r.uploader_type == @owner and r.archived == false)
        |> group_by([r, o], o.uuid)
        |> select([r, o], {o.uuid, count(r.id)})
        |> Repo.all()
        |> Enum.reduce(%{}, fn data, acc -> Map.put(acc, elem(data, 0), elem(data, 1)) end)

      rental_owner_wise_count =
        RentalPropertyPost
        |> join(:inner, [r], o in Owner, on: o.id == r.assigned_owner_id)
        |> where([r, o], o.uuid in ^owner_uuids and r.uploader_type == @owner and r.archived == false)
        |> group_by([r, o], o.uuid)
        |> select([r, o], {o.uuid, count(r.id)})
        |> Repo.all()
        |> Enum.reduce(%{}, fn data, acc -> Map.put(acc, elem(data, 0), elem(data, 1)) end)

      posts =
        posts
        |> Enum.map(fn pt ->
          assigned_owner =
            pt.assigned_owner
            |> Map.put(:resale_posts_count, resale_owner_wise_count[pt.assigned_owner.uuid])
            |> Map.put(:rental_posts_count, rental_owner_wise_count[pt.assigned_owner.uuid])
            |> Map.put(:is_broker, broker_phone_map[pt.assigned_owner.phone_number])

          pt
          |> Map.put(:assigned_owner, assigned_owner)
          |> Map.put(:matches_count, matches_count_map[pt.id]["count"])
          |> Map.put(:contacted_count, matches_count_map[pt.id]["contacted_count"])
        end)

      {posts, total_count, has_more_posts, expiry_wise_count}
    end
  end

  def fetch_all_client_posts(params) do
    response =
      if params["post_type"] == "resale" do
        params |> ResaleClientPost.fetch_resale_posts()
      else
        params |> RentalClientPost.fetch_rental_posts()
      end

    # for admin apis
    {posts, total_count, has_more_posts} = response
    post_ids = posts |> Enum.map(& &1["id"])

    matches_count_map =
      if params["post_type"] == "resale" do
        ResaleMatch
        |> where([rm], rm.resale_client_id in ^post_ids)
        |> Repo.all()
        |> Enum.reduce(%{}, fn data, acc ->
          Map.put(acc, data.resale_client_id, %{
            "count" => (acc[data.resale_client_id]["count"] || 0) + 1,
            "contacted_count" => (acc[data.resale_client_id]["contacted_count"] || 0) + if(data.already_contacted == true, do: 1, else: 0)
          })
        end)
      else
        RentalMatch
        |> where([rm], rm.rental_client_id in ^post_ids)
        |> Repo.all()
        |> Enum.reduce(%{}, fn data, acc ->
          Map.put(acc, data.rental_client_id, %{
            "count" => (acc[data.rental_client_id]["count"] || 0) + 1,
            "contacted_count" => (acc[data.rental_client_id]["contacted_count"] || 0) + if(data.already_contacted == true, do: 1, else: 0)
          })
        end)
      end

    posts =
      posts
      |> Enum.map(fn pt ->
        pt
        |> Map.put(:matches_count, matches_count_map[pt["id"]]["count"])
        |> Map.put(:contacted_count, matches_count_map[pt["id"]]["contacted_count"])
      end)

    {posts, total_count, has_more_posts}
  end

  def fetch_owner_posts_for_broker(logged_in_user, params) do
    broker = Accounts.get_broker_by_user_id(logged_in_user[:user_id])

    params =
      if is_nil(params["locality_ids"]) do
        params |> Map.put("city_id", logged_in_user[:operating_city])
      else
        params
      end

    {posts, total_count, has_more_posts, _expiry_wise_count} =
      if not is_nil(params["post_type"]) and Enum.member?(["rent", "resale"], params["post_type"]) do
        params |> fetch_all_property_posts(broker, true)
      else
        {rental_posts, rental_total_count, rental_has_more_posts, _rental_expiry_wise_count} = RentalPropertyPost.fetch_rental_posts(params, broker, true)

        {resale_posts, resale_total_count, resale_has_more_posts, _resale_expiry_wise_count} = ResalePropertyPost.fetch_resale_posts(params, broker, true)

        posts =
          (rental_posts ++ resale_posts)
          |> Enum.sort_by(fn post -> post[:inserted_at] |> Time.naive_to_epoch() end, &>=/2)

        is_filter_applied =
          if not is_nil(params["latitude"]) or
               not is_nil(params["longitude"]) or
               not is_nil(params["locality_ids"]) or
               not is_nil(params["building_ids"]) or
               not is_nil(params["configuration_type_ids"]) or
               not is_nil(params["furnishing_type_ids"]) or
               not is_nil(params["max_rent"]) or
               not is_nil(params["parking"]) or
               not is_nil(params["is_bachelor_allowed"]) or
               not is_nil(params["max_price"]) or
               (not is_nil(params["min_available_from"]) and not is_nil(params["max_available_from"])) or
               not is_nil(params["min_carpet_area"]),
             do: true,
             else: false

        posts =
          if is_filter_applied do
            posts |> Enum.sort_by(fn post -> post[:is_offline] end, &>=/2)
          else
            posts
          end

        total_count = rental_total_count + resale_total_count
        has_more_posts = rental_has_more_posts || resale_has_more_posts
        {posts, total_count, has_more_posts, %{}}
      end

    posts =
      if logged_in_user[:is_match_plus_active] == true,
        do: posts,
        else: mask_owner_info_in_posts(posts)

    {posts, total_count, has_more_posts}
  end

  def fetch_shortlisted_owner_posts(logged_in_user) do
    broker = Accounts.get_broker_by_user_id(logged_in_user[:user_id])
    rental_posts = RentalPropertyPost.fetch_shortlisted_owner_posts(broker)
    resale_posts = ResalePropertyPost.fetch_shortlisted_owner_posts(broker)

    posts =
      (rental_posts ++ resale_posts)
      |> Enum.sort_by(fn post -> {post[:shortlisted_at]} end, &>=/2)

    posts =
      if logged_in_user[:is_match_plus_active] == true,
        do: posts,
        else: mask_owner_info_in_posts(posts)

    {posts}
  end

  def fetch_all_posts_with_matches_v2(logged_in_user, _organization_id, user_id, page) do
    rental_client_posts = RentalMatch.rental_client_posts_with_matches(user_id, 4, true)

    rental_property_posts = RentalMatch.rental_property_posts_with_matches(user_id, 4, false)

    resale_client_posts = ResaleMatch.resale_client_posts_with_matches(user_id, 4, true)

    resale_property_posts = ResaleMatch.resale_property_posts_with_matches(user_id, 4, false)

    rental_client_posts_without_matches =
      RentalMatch.rental_client_posts_without_matches(
        user_id,
        rental_client_posts
      )

    rental_property_posts_without_matches =
      RentalMatch.rental_property_posts_without_matches(
        user_id,
        rental_property_posts,
        false
      )

    resale_client_posts_without_matches =
      ResaleMatch.resale_client_posts_without_matches(
        user_id,
        resale_client_posts
      )

    resale_property_posts_without_matches =
      ResaleMatch.resale_property_posts_without_matches(
        user_id,
        resale_property_posts,
        false
      )

    posts =
      rental_client_posts ++
        rental_property_posts ++
        resale_client_posts ++
        resale_property_posts ++
        rental_client_posts_without_matches ++
        rental_property_posts_without_matches ++
        resale_client_posts_without_matches ++
        resale_property_posts_without_matches

    total_posts = posts |> length

    posts =
      posts
      |> Enum.sort_by(
        fn %{post_in_context: pic, matches: matches} ->
          {
            # length(matches) != 0 && hd(matches).read == false,
            (length(matches) != 0 && hd(matches).inserted_at) || (pic.updation_time || pic.inserted_at)
          }
        end,
        &>=/2
      )
      |> Enum.slice(((page - 1) * @post_per_page)..(page * @post_per_page - 1))

    has_more_posts = page < Float.ceil(total_posts / @post_per_page)
    lock_posts = logged_in_user[:is_match_plus_active] != true

    posts =
      posts
      |> hide_owner_info_in_matches_home_posts()
      |> mask_owner_info_in_matches_home_posts(lock_posts)
      |> mark_shortlisted_info_in_matches_home(user_id)

    {:ok, posts, has_more_posts}
  end

  def fetch_all_posts_with_matches(_organization_id, user_id, page) do
    rental_client_posts = RentalMatch.rental_client_posts_with_matches(user_id, 4)

    rental_property_posts = RentalMatch.rental_property_posts_with_matches(user_id, 4)

    resale_client_posts = ResaleMatch.resale_client_posts_with_matches(user_id, 4)

    resale_property_posts = ResaleMatch.resale_property_posts_with_matches(user_id, 4)

    rental_client_posts_without_matches =
      RentalMatch.rental_client_posts_without_matches(
        user_id,
        rental_client_posts
      )

    rental_property_posts_without_matches =
      RentalMatch.rental_property_posts_without_matches(
        user_id,
        rental_property_posts
      )

    resale_client_posts_without_matches =
      ResaleMatch.resale_client_posts_without_matches(
        user_id,
        resale_client_posts
      )

    resale_property_posts_without_matches =
      ResaleMatch.resale_property_posts_without_matches(
        user_id,
        resale_property_posts
      )

    posts =
      rental_client_posts ++
        rental_property_posts ++
        resale_client_posts ++
        resale_property_posts ++
        rental_client_posts_without_matches ++
        rental_property_posts_without_matches ++
        resale_client_posts_without_matches ++
        resale_property_posts_without_matches

    total_posts = posts |> length

    posts =
      posts
      |> Enum.sort_by(
        fn %{post_in_context: pic, matches: matches} ->
          {
            # length(matches) != 0 && hd(matches).read == false,
            (length(matches) != 0 && hd(matches).inserted_at) || (pic.updation_time || pic.inserted_at)
          }
        end,
        &>=/2
      )
      |> Enum.slice(((page - 1) * @post_per_page)..(page * @post_per_page - 1))

    has_more_posts = page < Float.ceil(total_posts / @post_per_page)

    {:ok, posts, has_more_posts}
  end

  def fetch_all_expiring_posts(organization_id, user_id, page) do
    posts =
      RentalClientPost.fetch_all_expiring_posts(organization_id, user_id) ++
        RentalPropertyPost.fetch_all_expiring_posts(organization_id, user_id) ++
        ResaleClientPost.fetch_all_expiring_posts(organization_id, user_id) ++
        ResalePropertyPost.fetch_all_expiring_posts(organization_id, user_id)

    total_posts = posts |> length

    posts =
      posts
      |> Enum.sort_by(fn post -> {post.expires_in} end, &>=/2)
      |> Enum.slice(
        ((page - 1) * @expiring_post_per_page)..(page * @expiring_post_per_page -
                                                   1)
      )
      |> Enum.map(fn post -> post |> Map.delete(:assigned_to_me) end)

    has_more_posts = page < Float.ceil(total_posts / @expiring_post_per_page)

    {:ok, posts, has_more_posts}
  end

  def fetch_expired_posts(organization_id, user_id, page) do
    posts =
      RentalClientPost.fetch_all_expired_posts(organization_id, user_id) ++
        RentalPropertyPost.fetch_all_expired_posts(organization_id, user_id) ++
        ResaleClientPost.fetch_all_expired_posts(organization_id, user_id) ++
        ResalePropertyPost.fetch_all_expired_posts(organization_id, user_id)

    total_posts = posts |> length

    posts =
      posts
      |> Enum.sort_by(
        fn post ->
          {post.assigned_to_me, post.updation_time || post.inserted_at}
        end,
        &>=/2
      )
      |> Enum.slice(((page - 1) * @post_per_page)..(page * @post_per_page - 1))

    assigned_to_me_posts = posts |> Enum.map(fn post -> post |> Map.delete(:assigned_to_me) end)

    assigned_to_others_posts = []

    has_more_posts = page < Float.ceil(total_posts / @post_per_page)

    {:ok, assigned_to_me_posts, assigned_to_others_posts, total_posts, has_more_posts}
  end

  def fetch_unread_expired_posts(organization_id, user_id, page) do
    posts =
      RentalClientPost.fetch_all_unread_expired_posts(organization_id, user_id) ++
        RentalPropertyPost.fetch_all_unread_expired_posts(
          organization_id,
          user_id
        ) ++
        ResaleClientPost.fetch_all_unread_expired_posts(
          organization_id,
          user_id
        ) ++
        ResalePropertyPost.fetch_all_unread_expired_posts(
          organization_id,
          user_id
        )

    total_posts = posts |> length

    posts =
      posts
      |> Enum.sort_by(
        fn post ->
          {post.assigned_to_me, post.updation_time || post.inserted_at}
        end,
        &>=/2
      )
      |> Enum.slice(((page - 1) * @post_per_page)..(page * @post_per_page - 1))

    has_more_posts = page < Float.ceil(total_posts / @post_per_page)

    {:ok, posts, has_more_posts}
  end

  def unread_expired_posts_count(organization_id, user_id) do
    posts =
      RentalClientPost.fetch_all_unread_expired_posts(organization_id, user_id) ++
        RentalPropertyPost.fetch_all_unread_expired_posts(
          organization_id,
          user_id
        ) ++
        ResaleClientPost.fetch_all_unread_expired_posts(
          organization_id,
          user_id
        ) ++
        ResalePropertyPost.fetch_all_unread_expired_posts(
          organization_id,
          user_id
        )

    total_posts_count = posts |> length

    {:ok, total_posts_count}
  end

  def mark_all_expired_as_read(user_id) do
    RentalClientPost.mark_unread_expired_posts_as_read(user_id)
    RentalPropertyPost.mark_unread_expired_posts_as_read(user_id)
    ResaleClientPost.mark_unread_expired_posts_as_read(user_id)
    ResalePropertyPost.mark_unread_expired_posts_as_read(user_id)

    {:ok, "Successfully marked all expired as read"}
  end

  @post_classes [
    %{
      post_class: RentalClientPost,
      post_type: "rent",
      post_sub_type: "client",
      match_class: RentalMatch,
      report_post_class: ReportedRentalClientPost
    },
    %{
      post_class: RentalPropertyPost,
      post_type: "rent",
      post_sub_type: "property",
      match_class: RentalMatch,
      report_post_class: ReportedRentalPropertyPost,
      contact_post_class: ContactedRentalPropertyPost
    },
    %{
      post_class: ResaleClientPost,
      post_type: "resale",
      post_sub_type: "client",
      match_class: ResaleMatch,
      report_post_class: ReportedResaleClientPost
    },
    %{
      post_class: ResalePropertyPost,
      post_type: "resale",
      post_sub_type: "property",
      match_class: ResaleMatch,
      report_post_class: ReportedResalePropertyPost,
      contact_post_class: ContactedResalePropertyPost
    }
  ]

  @type_and_sub_type %{
    "rent_property" => %{
      "type" => 1,
      "sub_type" => 1,
      "title" => "Rental Property"
    },
    "rent_client" => %{
      "type" => 1,
      "sub_type" => 2,
      "title" => "Rental Client"
    },
    "resale_property" => %{
      "type" => 2,
      "sub_type" => 1,
      "title" => "Resale Property"
    },
    "resale_client" => %{
      "type" => 2,
      "sub_type" => 2,
      "title" => "Resale Client"
    }
  }

  def get_type_and_sub_type(post_type_sub_type) do
    @type_and_sub_type[post_type_sub_type]
  end

  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"shortlist_#{post_type}_#{post_sub_type}_owner_post")(
          user_id,
          post_uuid,
          post_type,
          addition
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "Post not found!"}

        post ->
          if post.uploader_type == @owner do
            broker = Accounts.get_broker_by_user_id(user_id)

            [status, content] =
              case post_type do
                "rent" ->
                  post_uuids = broker.shortlisted_rental_posts |> Enum.map(& &1["uuid"])

                  if addition do
                    if Enum.member?(post_uuids, post_uuid) do
                      [:error, "Post is already present in your shortlist"]
                    else
                      [
                        :ok,
                        %{
                          "shortlisted_rental_posts" =>
                            [%{"uuid" => post_uuid, "shortlisted_at" => NaiveDateTime.utc_now()}] ++
                              List.delete_at(broker.shortlisted_rental_posts, 99)
                        }
                      ]
                    end
                  else
                    if Enum.member?(post_uuids, post_uuid) do
                      item = broker.shortlisted_rental_posts |> Enum.find(&(&1["uuid"] == post_uuid))
                      [:ok, %{"shortlisted_rental_posts" => List.delete(broker.shortlisted_rental_posts, item)}]
                    else
                      [:error, "Post is not present in your shortlist"]
                    end
                  end

                "resale" ->
                  post_uuids = broker.shortlisted_resale_posts |> Enum.map(& &1["uuid"])

                  if addition do
                    if Enum.member?(post_uuids, post_uuid) do
                      [:error, "Post is already present in your shortlist"]
                    else
                      [
                        :ok,
                        %{
                          "shortlisted_resale_posts" =>
                            [%{"uuid" => post_uuid, "shortlisted_at" => NaiveDateTime.utc_now()}] ++
                              List.delete_at(broker.shortlisted_resale_posts, 99)
                        }
                      ]
                    end
                  else
                    if Enum.member?(post_uuids, post_uuid) do
                      item = broker.shortlisted_resale_posts |> Enum.find(&(&1["uuid"] == post_uuid))
                      [:ok, %{"shortlisted_resale_posts" => List.delete(broker.shortlisted_resale_posts, item)}]
                    else
                      [:error, "Post is not present in your shortlist"]
                    end
                  end
              end

            if status == :ok do
              Broker.changeset(broker, content) |> Repo.update!()

              message =
                if addition,
                  do: "You have successfully added post to the shortlist!",
                  else: "You have successfully removed post from the shortlist!"

              {:ok, message}
            else
              {:error, content}
            end
          else
            {:error, "Only Owner listings are allowed for shortlisting"}
          end
      end
    end
  end)

  @post_classes
  |> Enum.filter(fn pc -> pc.post_sub_type == "property" end)
  |> Enum.each(fn %{
                    post_type: post_type
                  } ->
    def unquote(:"mark_#{post_type}_property_owner_post_contacted")(
          user_id,
          post_uuid,
          post_type,
          is_contact_successful
        ) do
      broker = Accounts.get_broker_by_user_id(user_id)

      case post_type do
        "rent" ->
          case Repo.get_by(RentalPropertyPost, uuid: post_uuid) do
            nil ->
              {:error, "Post not found! #{post_uuid} #{post_type}"}

            post ->
              if post.uploader_type == @owner do
                contacted_post = ContactedRentalPropertyPost.mark_contacted(post.id, broker.id, is_contact_successful)
                {:ok, contacted_post}
              else
                {:error, "Only Owner listings can be marked as contacted"}
              end
          end

        "resale" ->
          case Repo.get_by(ResalePropertyPost, uuid: post_uuid) do
            nil ->
              {:error, "Post not found! #{post_uuid} #{post_type}"}

            post ->
              if post.uploader_type == @owner do
                contacted_post = ContactedResalePropertyPost.mark_contacted(post.id, broker.id, is_contact_successful)
                {:ok, contacted_post}
              else
                {:error, "Only Owner listings can be marked as contacted"}
              end
          end
      end
    end
  end)

  @doc """
   Refreshing reported property posts
  """
  @post_classes
  |> Enum.filter(fn pc -> pc.post_sub_type == "property" end)
  |> Enum.each(fn %{
                    post_type: post_type
                  } ->
    def unquote(:"refresh_reported_#{post_type}_property_owner_post")(
          user_id,
          post_id,
          refresh_note
        ) do
      {status, content} =
        case unquote(post_type) do
          "rent" ->
            ReportedRentalPropertyPost.refresh_posts(post_id, user_id, refresh_note)

          "resale" ->
            ReportedResalePropertyPost.refresh_posts(post_id, user_id, refresh_note)
        end

      if status == :ok do
        {:ok, content}
      else
        {:error, content}
      end
    end
  end)

  @doc """
  Macro for ARCHIVE POST METHODS
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"archive_#{post_type}_#{post_sub_type}_post")(
          user_id,
          post_uuid,
          broker_role_id,
          broker_organization_id,
          archived_reason_id
        ) do
      mark_archive_params = %{
        archived: true,
        archived_by_id: user_id,
        archived_reason_id: archived_reason_id,
        updation_time: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }

      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "Post not found!"}

        post ->
          post = post |> Repo.preload(:assigned_user)

          if (broker_role_id == BrokerRole.admin().id and
                broker_organization_id == post.assigned_user.organization_id) or
               post.assigned_user_id == user_id do
            apply(unquote(post_class), :changeset, [post, mark_archive_params])
            |> Repo.update()
          else
            {:error, "Either admin or assigned user of post is allowed to expire"}
          end
      end
    end
  end)

  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"archive_#{post_type}_#{post_sub_type}_owner_post")(
          employee_user_id,
          post_uuid,
          employee_role_id,
          archived_reason_id,
          action_via_slash \\ false
        ) do
      archive_owner_post(
        unquote(post_class),
        unquote(post_type),
        unquote(post_sub_type),
        employee_user_id,
        post_uuid,
        employee_role_id,
        archived_reason_id,
        action_via_slash
      )
    end
  end)

  def archive_owner_post(
        post_class,
        post_type,
        post_sub_type,
        employee_user_id,
        post_uuid,
        employee_role_id,
        archived_reason_id,
        action_via_slash \\ false
      ) do
    current_time = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    mark_archive_params = %{
      archived: true,
      archived_by_employees_credentials_id: employee_user_id,
      archived_reason_id: archived_reason_id,
      last_archived_at: current_time,
      updation_time: current_time,
      action_via_slash: action_via_slash
    }

    case Repo.get_by(post_class, uuid: post_uuid) do
      nil ->
        {:error, "Post not found!"}

      post ->
        if post.uploader_type == @owner do
          if Enum.member?(
               [
                 EmployeeRole.owner_supply_admin().id,
                 EmployeeRole.super().id,
                 EmployeeRole.owner_supply_operations().id,
                 EmployeeRole.bot_admin_user().id
               ],
               employee_role_id
             ) do
            changeset = apply(post_class, :changeset, [post, mark_archive_params])
            post_changeset = Repo.update!(changeset)

            Log.log(
              post_changeset.id,
              "#{post_type}_#{post_sub_type}_posts",
              employee_user_id,
              "employee",
              changeset.changes
            )

            if not is_nil(post.assigned_owner) do
              post = post |> Repo.preload(:assigned_owner)

              send_referral_mssg_after_deactivating_posts(
                post.assigned_owner.phone_number,
                post.assigned_owner.name,
                post_type
              )
            end

            {:ok, post_changeset}
          else
            {:error, "Only Owner Supply Admin is allowed to expire"}
          end
        else
          {:error, "Only Owner listings are allowed to expire"}
        end
    end
  end

  @doc """
  Macro for VERIFY POST METHODS
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"verify_#{post_type}_#{post_sub_type}_owner_post")(
          employee_user_id,
          post_uuid,
          employee_role_id
        ) do
      verify_owner_post(
        unquote(post_class),
        unquote(post_type),
        employee_user_id,
        post_uuid,
        employee_role_id
      )
    end
  end)

  def verify_owner_post(post_class, post_type, employee_user_id, post_uuid, employee_role_id) do
    current_time = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    mark_verified_params = %{
      is_verified: true,
      verified_by_employees_credentials_id: employee_user_id,
      last_verified_at: current_time,
      updation_time: current_time
    }

    case Repo.get_by(post_class, uuid: post_uuid) do
      nil ->
        {:error, "Post not found!"}

      post ->
        post = post |> Repo.preload(:assigned_owner)

        if not post.archived and post.uploader_type == @owner do
          if Enum.member?(
               [
                 EmployeeRole.owner_supply_admin().id,
                 EmployeeRole.super().id,
                 EmployeeRole.owner_supply_operations().id
               ],
               employee_role_id
             ) do
            changeset = apply(post_class, :changeset, [post, mark_verified_params])

            case Repo.update(changeset) do
              {:ok, post} ->
                if not is_nil(post.assigned_owner) and not is_nil(post.assigned_owner.phone_number) do
                  case post_type do
                    "rent" ->
                      send_verified_whatsapp_message(post, changeset.changes, employee_user_id, "employee", @rent_map)

                    "resale" ->
                      send_verified_whatsapp_message(post, changeset.changes, employee_user_id, "employee", @resale_map)
                  end
                else
                  {:ok, post}
                end

              {:error, _reason} = err ->
                err
            end
          else
            {:error, "Only Owner Supply Admin and Owner Supply Operations is allowed to verify"}
          end
        else
          {:error, "Only non archived Owner listings are allowed to be verified"}
        end
    end
  end

  defp get_post_changeset_by_uuid(params, module, post_uuid) do
    case Repo.get_by(module, uuid: post_uuid) |> Repo.preload(:assigned_owner) do
      nil ->
        {:error, "Post not found"}

      post ->
        {:ok, post |> module.changeset(params)}
    end
  end

  def edit_owner_property_post(params, post_uuid, _post_type = "rent") do
    edit_owner_property_post(params, post_uuid, RentalPropertyPost)
  end

  def edit_owner_property_post(params, post_uuid, _post_type = "resale") do
    edit_owner_property_post(params, post_uuid, ResalePropertyPost)
  end

  def edit_owner_property_post(params, post_uuid, module) do
    params
    |> maybe_add_edited_owner()
    |> module.filter_edit_fields(["uuid", "employee_cred_id"])
    |> parse_available_from()
    |> add_edited_credentials()
    |> get_post_changeset_by_uuid(module, post_uuid)
    |> case do
      {:ok, changeset} ->
        changeset
        |> Repo.update()

      {:error, error_mssg} ->
        {:error, error_mssg}
    end
  end

  def get_post_details_for_whatsapp_message(post, post_type) do
    case post_type do
      "rent" ->
        tenant_preference =
          if not is_nil(post.is_bachelor_allowed) do
            "Family / Bachelor"
          else
            "Only Family"
          end

        [
          "#{post.assigned_owner.name}",
          "#{post.configuration_type.name}",
          "#{post.building.name}",
          "#{post.rent_expected}",
          "#{post.furnishing_type.name}",
          "#{tenant_preference}"
        ]

      "resale" ->
        [
          "#{post.assigned_owner.name}",
          "#{post.configuration_type.name}",
          "#{post.building.name}",
          "#{post.price}",
          "#{post.carpet_area}",
          "#{post.parking}"
        ]
    end
  end

  @doc """
  Macro for REFRESH POST METHODS
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"refresh_#{post_type}_#{post_sub_type}_post")(
          user_id,
          post_uuid,
          broker_role_id,
          broker_organization_id
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "Post not found!"}

        post ->
          post = post |> Repo.preload(:assigned_user)

          if (broker_role_id == BrokerRole.admin().id and
                broker_organization_id == post.assigned_user.organization_id) or
               post.assigned_user_id == user_id do
            {building_ids, configuration} =
              case unquote(post_sub_type) do
                "client" -> {post.building_ids, post.configuration_type_ids}
                _ -> {[post.building_id], post.configuration_type_id}
              end

            params = %{
              "configuration_type_ids" => configuration,
              "configuration_type_id" => configuration
            }

            {:ok, buildings} = Buildings.get_building_data_from_ids([], building_ids)

            refresh_days =
              get_expiry_days(
                unquote(post_type),
                unquote(post_sub_type),
                buildings,
                params
              )

            mark_refresh_params = %{
              expires_in: refresh_days |> Time.set_expiry_time(),
              refreshed_by_id: user_id,
              updation_time: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
            }

            apply(unquote(post_class), :changeset, [post, mark_refresh_params])
            |> Repo.update()
          else
            {:error, "Either admin or assigned user of post is allowed to refresh"}
          end
      end
    end
  end)

  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"refresh_#{post_type}_#{post_sub_type}_owner_post")(
          employee_user_id,
          post_uuid,
          employee_role_id,
          refreshed_reason_id,
          action_via_slash \\ false
        ) do
      refresh_owner_post(
        unquote(post_class),
        unquote(post_type),
        unquote(post_sub_type),
        employee_user_id,
        post_uuid,
        employee_role_id,
        refreshed_reason_id,
        action_via_slash
      )
    end
  end)

  def refresh_owner_post(post_class, post_type, post_sub_type, employee_user_id, post_uuid, employee_role_id, refreshed_reason_id, action_via_slash \\ false) do
    case Repo.get_by(post_class, uuid: post_uuid) do
      nil ->
        {:error, "Post not found!"}

      post ->
        if post.uploader_type == @owner do
          if Enum.member?(
               [EmployeeRole.owner_supply_admin().id, EmployeeRole.super().id, EmployeeRole.bot_admin_user().id],
               employee_role_id
             ) do
            {building_ids, configuration} =
              case post_sub_type do
                "client" -> {post.building_ids, post.configuration_type_ids}
                _ -> {[post.building_id], post.configuration_type_id}
              end

            params = %{
              "configuration_type_ids" => configuration,
              "configuration_type_id" => configuration
            }

            {:ok, buildings} = Buildings.get_building_data_from_ids([], building_ids)

            refresh_days =
              get_expiry_days(
                post_type,
                post_sub_type,
                buildings,
                params
              )

            current_time = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

            mark_refresh_params = %{
              expires_in: refresh_days |> Time.set_expiry_time(),
              refreshed_by_employees_credentials_id: employee_user_id,
              refreshed_reason_id: refreshed_reason_id,
              last_refreshed_at: current_time,
              updation_time: current_time,
              action_via_slash: action_via_slash
            }

            {status, response} =
              apply(post_class, :changeset, [post, mark_refresh_params])
              |> Repo.update()

            if post.is_verified == false and status == :ok do
              verify_owner_post(
                post_class,
                post_type,
                employee_user_id,
                post_uuid,
                employee_role_id
              )
            end

            {status, response}
          else
            {:error, "Only Owner Supply Admin is allowed to refresh"}
          end
        else
          {:error, "Only Owner listings are allowed to be refreshed"}
        end
    end
  end

  @doc """
  Macro for RESTORE POST METHODS
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"restore_#{post_type}_#{post_sub_type}_post")(
          user_id,
          post_uuid
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "Post not found!"}

        post ->
          {building_ids, configuration} =
            case unquote(post_sub_type) do
              "client" -> {post.building_ids, post.configuration_type_ids}
              _ -> {[post.building_id], post.configuration_type_id}
            end

          params = %{
            "configuration_type_ids" => configuration,
            "configuration_type_id" => configuration
          }

          {:ok, buildings} = Buildings.get_building_data_from_ids([], building_ids)

          refresh_days =
            get_expiry_days(
              unquote(post_type),
              unquote(post_sub_type),
              buildings,
              params
            )

          restore_params = %{
            expires_in: refresh_days |> Time.set_expiry_time(),
            refreshed_by_id: user_id,
            archived: false,
            updation_time: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }

          apply(unquote(post_class), :changeset, [post, restore_params])
          |> Repo.update()
      end
    end
  end)

  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"restore_#{post_type}_#{post_sub_type}_owner_post")(
          employee_user_id,
          post_uuid,
          employee_role_id
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "Post not found!"}

        post ->
          if post.uploader_type == @owner do
            if Enum.member?([EmployeeRole.owner_supply_admin().id, EmployeeRole.super().id], employee_role_id) do
              {building_ids, configuration} =
                case unquote(post_sub_type) do
                  "client" -> {post.building_ids, post.configuration_type_ids}
                  _ -> {[post.building_id], post.configuration_type_id}
                end

              params = %{
                "configuration_type_ids" => configuration,
                "configuration_type_id" => configuration
              }

              {:ok, buildings} = Buildings.get_building_data_from_ids([], building_ids)

              refresh_days =
                get_expiry_days(
                  unquote(post_type),
                  unquote(post_sub_type),
                  buildings,
                  params
                )

              restore_params = %{
                expires_in: refresh_days |> Time.set_expiry_time(),
                refreshed_by_employees_credentials_id: employee_user_id,
                archived: false,
                updation_time: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
              }

              apply(unquote(post_class), :changeset, [post, restore_params])
              |> Repo.update()
            else
              {:error, "Only Owner Supply Admin is allowed to restore"}
            end
          else
            {:error, "Only Owner listings are allowed to be restored"}
          end
      end
    end
  end)

  @doc """
  Macro for REASSIGN POST METHODS
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"reassign_#{post_type}_#{post_sub_type}_post")(
          user_id,
          assigned_user_id,
          post_uuid
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "Post not found!"}

        post ->
          params = %{
            assigned_user_id: assigned_user_id
          }

          apply(unquote(post_class), :changeset, [post, params])
          |> Repo.update()

          field = String.to_atom("#{unquote(post_type)}_#{unquote(post_sub_type)}_post_id")

          field_query = [{field, post.id}]

          results =
            PostAssignmentHistory
            |> where(^field_query)
            |> where([p], is_nil(p.end_date))
            |> order_by([p], desc: p.inserted_at)
            |> Repo.all()

          case results |> List.first() do
            nil ->
              "PostAssignmentHistory not found!"

            pah ->
              update_history_params = %{
                "end_date" => NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
                "changed_by_id" => user_id
              }

              apply(unquote(PostAssignmentHistory), :changeset, [
                pah,
                update_history_params
              ])
              |> Repo.update()
          end

          new_history_params = %{
            "start_date" => NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            "#{unquote(post_type)}_#{unquote(post_sub_type)}_post_id" => post.id,
            "user_id" => assigned_user_id
          }

          apply(unquote(PostAssignmentHistory), :changeset, [new_history_params])
          |> Repo.insert()
      end
    end
  end)

  @doc """
  Macro for REPORT POST METHODS
  """
  @post_classes
  |> Enum.each(fn %{
                    report_post_class: report_post_class,
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"report_#{post_type}_#{post_sub_type}_post")(
          user_id,
          post_uuid,
          reason_id
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "Post not found!"}

        post ->
          if post.assigned_user_id == user_id do
            {:error, "Reporting is allowed only for other's post, not one's own post."}
          else
            report_post_params = %{
              post_id: post.id,
              reported_by_id: user_id,
              report_post_reason_id: reason_id
            }

            post = post |> Repo.preload(:assigned_owner)

            if not post.archived do
              if post.uploader_type == @owner and not is_nil(post.assigned_owner) do
                owner_phone_number =
                  post.assigned_owner.phone_number
                  |> get_phone_number_with_country_code()

                if not is_nil(owner_phone_number) do
                  post = post |> Repo.preload([:building, :configuration_type])
                  button_reply_payload = get_whatsapp_button_reply_payload_for_refresh_archive(unquote(post_type), post.uuid)

                  case unquote(post_type) do
                    "rent" ->
                      post = post |> Repo.preload(:furnishing_type)
                      latest_report_details = ReportedRentalPropertyPost.get_reported_rental_property_details(post.id)

                      today_beginning_of_day =
                        Timex.now()
                        |> Timex.Timezone.convert("Asia/Kolkata")
                        |> Timex.beginning_of_day()
                        |> DateTime.to_unix()

                      last_reported_at = get_latest_reported_time(latest_report_details[:last_reported_at])

                      if is_nil(last_reported_at) or
                           (not is_nil(last_reported_at) and last_reported_at <= today_beginning_of_day) do
                        Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
                          owner_phone_number,
                          @rent_map.expiry_mssg_template,
                          get_post_details_for_whatsapp_message(post, unquote(post_type)),
                          %{"entity_type" => @rent_map.table, "entity_id" => post.id},
                          true,
                          button_reply_payload
                        ])
                      end

                    "resale" ->
                      latest_report_details = ReportedResalePropertyPost.get_reported_resale_property_details(post.id)

                      today_beginning_of_day =
                        Timex.now()
                        |> Timex.Timezone.convert("Asia/Kolkata")
                        |> Timex.beginning_of_day()
                        |> DateTime.to_unix()

                      last_reported_at = get_latest_reported_time(latest_report_details[:last_reported_at])

                      if is_nil(last_reported_at) or
                           (not is_nil(last_reported_at) and last_reported_at <= today_beginning_of_day) do
                        Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
                          owner_phone_number,
                          @resale_map.expiry_mssg_template,
                          get_post_details_for_whatsapp_message(post, unquote(post_type)),
                          %{"entity_type" => @resale_map.table, "entity_id" => post.id},
                          true,
                          button_reply_payload
                        ])
                      end
                  end
                end
              end

              apply(unquote(report_post_class), :report_post, [report_post_params])
            else
              {:error, "Only non-archived post can be reported"}
            end
          end
      end
    end
  end)

  def get_latest_reported_time(nil), do: nil

  def get_latest_reported_time(last_reported_at) do
    last_reported_at |> Timex.to_datetime() |> DateTime.to_unix()
  end

  def get_whatsapp_button_reply_payload_for_refresh_archive(post_type, post_uuid) do
    [
      %{
        index: "0",
        payload: "{\"entity_type\": \"post\", \"post_type\": \"#{post_type}\", \"post_uuid\" : \"#{post_uuid}\", \"action\": \"refresh\"}"
      },
      %{
        index: "1",
        payload: "{\"entity_type\": \"post\", \"post_type\": \"#{post_type}\", \"post_uuid\" : \"#{post_uuid}\", \"action\": \"deactivate\"}"
      }
    ]
  end

  def get_whatsapp_button_reply_payload_for_verify_archive(post_type, post_uuid) do
    [
      %{
        index: "0",
        payload: "{\"entity_type\": \"post\", \"post_type\": \"#{post_type}\", \"post_uuid\" : \"#{post_uuid}\", \"action\": \"verify\"}"
      },
      %{
        index: "1",
        payload: "{\"entity_type\": \"post\", \"post_type\": \"#{post_type}\", \"post_uuid\" : \"#{post_uuid}\", \"action\": \"deactivate\"}"
      }
    ]
  end

  @doc """
  Macro for POST COUNT MATCHES METHODS (Pre Commit)
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: _post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type,
                    match_class: match_class
                  } ->
    def unquote(:"fetch_count_#{post_type}_#{post_sub_type}_post_matches")(
          assigned_user_id,
          configuration_type_ids,
          building_ids,
          is_bachelor,
          blocked_users,
          is_test_post,
          params
        ) do
      post_sub_type_suffle = if unquote(post_sub_type) == "client", do: "property", else: "client"

      building_ids =
        if unquote(post_sub_type) == "client",
          do: building_ids,
          else: [building_ids]

      case Buildings.get_ids_from_uids(building_ids) do
        {:ok, building_ids} ->
          building_ids =
            if unquote(post_sub_type) == "client",
              do: building_ids,
              else: building_ids |> List.first()

          query_method_name = String.to_atom("#{unquote(post_type)}_#{post_sub_type_suffle}_matches_count_query")

          query =
            apply(unquote(match_class), query_method_name, [
              assigned_user_id,
              configuration_type_ids,
              building_ids,
              is_bachelor,
              blocked_users,
              is_test_post,
              params
            ])

          result = query |> Repo.all()
          brokers_count = result |> length

          matches_count = result |> Enum.reduce(0, fn %{count: count}, acc -> count + acc end)

          {:ok, brokers_count, matches_count}

        {:error, message} ->
          {:error, message}
      end
    end
  end)

  @doc """
  Macro for POST MATCHES METHODS
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type,
                    match_class: match_class
                  } ->
    def unquote(:"fetch_#{post_type}_#{post_sub_type}_post_matches")(
          user_id,
          post_uuid,
          page
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "#{unquote(post_type)} #{unquote(post_sub_type)} post not found!"}

        post ->
          # start = System.monotonic_time(:millisecond)
          matches_method_name = String.to_atom("#{unquote(post_type)}_#{unquote(post_sub_type)}_post_matches")

          {matches, total_brokers_count} =
            apply(unquote(match_class), matches_method_name, [
              user_id,
              post.id,
              page,
              @broker_per_page
            ])

          post_context_method_name = String.to_atom("#{unquote(post_type)}_#{unquote(post_sub_type)}_post_context")

          post_in_context =
            apply(unquote(match_class), post_context_method_name, [
              user_id,
              post.id
            ])

          # time_spent = System.monotonic_time(:millisecond) - start
          # IO.puts("Executed #{time_spent} millisecond")

          {:ok, {post_in_context, matches, total_brokers_count}}
      end
    end
  end)

  @doc """
  Macro for POST MATCHES METHODS
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type,
                    match_class: match_class
                  } ->
    def unquote(:"fetch_#{post_type}_#{post_sub_type}_post_matches_v1")(
          user_id,
          post_uuid,
          page
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "#{unquote(post_type)} #{unquote(post_sub_type)} post not found!"}

        post ->
          # start = System.monotonic_time(:millisecond)
          matches_method_name = String.to_atom("#{unquote(post_type)}_#{unquote(post_sub_type)}_post_matches_v1")

          {matches, total_matches_count, has_more_matches} =
            apply(unquote(match_class), matches_method_name, [
              user_id,
              post.id,
              page,
              @post_per_page
            ])

          post_context_method_name = String.to_atom("#{unquote(post_type)}_#{unquote(post_sub_type)}_post_context")

          post_in_context =
            apply(unquote(match_class), post_context_method_name, [
              user_id,
              post.id
            ])

          # time_spent = System.monotonic_time(:millisecond) - start
          # IO.puts("Executed #{time_spent} millisecond")

          {:ok, {post_in_context, matches, total_matches_count, has_more_matches}}
      end
    end
  end)

  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type,
                    match_class: match_class
                  } ->
    def unquote(:"fetch_#{post_type}_#{post_sub_type}_post_matches_v2")(
          logged_in_user,
          post_uuid,
          page
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "#{unquote(post_type)} #{unquote(post_sub_type)} post not found!"}

        post ->
          # start = System.monotonic_time(:millisecond)
          matches_method_name = String.to_atom("#{unquote(post_type)}_#{unquote(post_sub_type)}_post_matches_v2")
          user_id = logged_in_user[:user_id]

          {matches, total_matches_count, has_more_matches} =
            apply(unquote(match_class), matches_method_name, [
              user_id,
              post.id,
              page,
              @post_per_page
            ])

          lock_posts = logged_in_user[:is_match_plus_active] != true

          matches =
            matches
            |> mask_owner_info_in_posts(lock_posts)
            |> hide_owner_info_for_assisted_posts()
            |> mark_shortlisted_info_in_matches(user_id)

          post_context_method_name = String.to_atom("#{unquote(post_type)}_#{unquote(post_sub_type)}_post_context")

          post_in_context =
            apply(unquote(match_class), post_context_method_name, [
              user_id,
              post.id
            ])

          # time_spent = System.monotonic_time(:millisecond) - start
          # IO.puts("Executed #{time_spent} millisecond")

          {:ok, {post_in_context, matches, total_matches_count, has_more_matches}}
      end
    end
  end)

  @doc """
  Macro for MORE POST MATCHES WITH BROKER METHODS
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type,
                    match_class: match_class
                  } ->
    def unquote(:"fetch_#{post_type}_#{post_sub_type}_more_post_matches_with_broker")(
          user_id,
          post_uuid,
          broker_uuid,
          _page
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "#{unquote(post_type)} #{unquote(post_sub_type)} post not found!"}

        post ->
          case Accounts.uuid_to_id(broker_uuid) do
            {:error, _message} ->
              {:error, "Broker not found!"}

            {:ok, broker_user_id} ->
              # start = System.monotonic_time(:millisecond)
              matches_method_name = String.to_atom("#{unquote(post_type)}_#{unquote(post_sub_type)}_post_more_matches_for_broker")

              matches =
                apply(unquote(match_class), matches_method_name, [
                  user_id,
                  post.id,
                  @matches_per_broker,
                  broker_user_id
                ])

              # time_spent = System.monotonic_time(:millisecond) - start
              # IO.puts("Executed #{time_spent} millisecond")

              {:ok, matches}
          end
      end
    end
  end)

  @doc """
  Macro for OWN POST MATCHES METHODS
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type,
                    match_class: match_class
                  } ->
    def unquote(:"fetch_#{post_type}_#{post_sub_type}_own_post_matches")(
          user_id,
          post_uuid,
          _page
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "#{unquote(post_type)} #{unquote(post_sub_type)} post not found!"}

        post ->
          # start = System.monotonic_time(:millisecond)
          matches_method_name = String.to_atom("#{unquote(post_type)}_#{unquote(post_sub_type)}_post_own_matches")

          matches = apply(unquote(match_class), matches_method_name, [user_id, post.id])

          post_context_method_name = String.to_atom("#{unquote(post_type)}_#{unquote(post_sub_type)}_match_context")

          post_in_context =
            apply(unquote(match_class), post_context_method_name, [
              user_id,
              post.id
            ])

          # time_spent = System.monotonic_time(:millisecond) - start
          # IO.puts("Executed #{time_spent} millisecond")

          {:ok, {post_in_context, matches}}
      end
    end
  end)

  @doc """
  Macro for POST related data
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"get_#{post_type}_#{post_sub_type}_post_data")(post_id) do
      case Repo.get_by(unquote(post_class), id: post_id) do
        nil ->
          {:error, "Post not found!"}

        post ->
          broker_details =
            if not is_nil(post.assigned_user_id) do
              Credential.user_credentials_query(post.assigned_user_id)
              |> Repo.one()
            else
              %{}
            end

          broker_details =
            put_in(
              broker_details,
              [:profile_pic_url],
              broker_details[:profile_image] || ""
            )

          broker_details =
            for {key, val} <- broker_details,
                into: %{},
                do: {Atom.to_string(key), val}

          type_and_sub_type = get_type_and_sub_type("#{unquote(post_type)}_#{unquote(post_sub_type)}")

          post_data = apply(unquote(post_class), :get_post, [post_id])

          post_data =
            put_in(
              post_data,
              ["uuid"],
              "#{unquote(post_type)}/#{unquote(post_sub_type)}/" <>
                post_data["uuid"]
            )

          %{"assigned_to" => broker_details}
          |> Map.merge(type_and_sub_type)
          |> Map.merge(post_data)
      end
    end
  end)

  @doc """
  Macro for making POST irrelevant
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"mark_#{post_type}_#{post_sub_type}_posts_irrelevant")(
          logged_in_user_id,
          post_uuids
        ) do
      case unquote(post_class)
           |> where([p], p.uuid in ^post_uuids)
           |> Repo.all()
           |> Enum.map(& &1.id) do
        [] ->
          {:error, "Posts not found!"}

        post_ids ->
          apply(unquote(post_class), :mark_post_matches_irrelevant, [
            logged_in_user_id,
            post_ids
          ])
      end
    end
  end)

  @doc """
  Macro for making Match as read
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"mark_#{post_type}_#{post_sub_type}_match_read")(
          logged_in_user_id,
          post_uuids
        ) do
      case unquote(post_class)
           |> where([p], p.uuid in ^post_uuids)
           |> Repo.all()
           |> Enum.map(& &1.id) do
        [] ->
          {:error, "Posts not found!"}

        post_ids ->
          apply(unquote(post_class), :mark_post_matches_as_read, [
            logged_in_user_id,
            post_ids
          ])
      end
    end
  end)

  @doc """
  Macro for fetching expired posts
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type
                  } ->
    def unquote(:"fetch_#{post_type}_#{post_sub_type}_soon_to_expire_posts")() do
      apply(unquote(post_class), :fetch_soon_to_expire_posts, [])
    end
  end)

  @doc """
  Macro for triggering match for a post
  """
  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type,
                    match_class: match_class
                  } ->
    def unquote(:"trigger_#{post_type}_#{post_sub_type}_matches")(
          logged_in_user,
          post_uuid
        ) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "Post not found!"}

        post ->
          blocked_users = BlockedUser.fetch_blocked_users(logged_in_user.user_id)

          post_sub_type_shuffle =
            if unquote(post_sub_type) == "client",
              do: "property",
              else: "client"

          method_name = String.to_atom("fetch_#{unquote(post_type)}_matched_#{post_sub_type_shuffle}_ids")

          exclude_matched_post_ids = apply(unquote(match_class), method_name, [post.id])

          ProcessPostMatchWorker.perform(
            unquote(post_type),
            unquote(post_sub_type),
            post.id,
            blocked_users,
            exclude_matched_post_ids,
            post.test_post
          )
      end
    end
  end)

  @post_classes
  |> Enum.each(fn %{
                    post_class: post_class,
                    post_type: post_type,
                    post_sub_type: post_sub_type,
                    match_class: match_class
                  } ->
    def unquote(:"trigger_#{post_type}_#{post_sub_type}_owner_matches")(post_uuid) do
      case Repo.get_by(unquote(post_class), uuid: post_uuid) do
        nil ->
          {:error, "Post not found!"}

        post ->
          blocked_users = []

          post_sub_type_shuffle =
            if unquote(post_sub_type) == "client",
              do: "property",
              else: "client"

          method_name = String.to_atom("fetch_#{unquote(post_type)}_matched_#{post_sub_type_shuffle}_ids")

          exclude_matched_post_ids = apply(unquote(match_class), method_name, [post.id])

          ProcessPostMatchWorker.perform(
            unquote(post_type),
            unquote(post_sub_type),
            post.id,
            blocked_users,
            exclude_matched_post_ids,
            post.test_post
          )
      end
    end
  end)

  def report_all_matches_with_broker(logged_in_user_id, broker_uuid) do
    case Accounts.uuid_to_id(broker_uuid) do
      {:error, _message} ->
        {:error, "Broker not found!"}

      {:ok, broker_user_id} ->
        RentalMatch.mark_matches_against_each_other_as_irrelevant(
          logged_in_user_id,
          broker_user_id
        )

        ResaleMatch.mark_matches_against_each_other_as_irrelevant(
          logged_in_user_id,
          broker_user_id
        )

        {:ok, "Successfully reported"}
    end
  end

  # def report_match do

  # end

  def fetch_all_matches_with_broker(logged_in_user_id, broker_uuid, page) do
    case Accounts.uuid_to_id(broker_uuid) do
      {:error, _message} ->
        {:error, "Broker not found!"}

      {:ok, broker_user_id} ->
        posts =
          RentalMatch.rental_matches_with_broker_properties(
            logged_in_user_id,
            broker_user_id
          ) ++
            RentalMatch.rental_matches_with_broker_clients(
              logged_in_user_id,
              broker_user_id
            ) ++
            ResaleMatch.resale_matches_with_broker_properties(
              logged_in_user_id,
              broker_user_id
            ) ++
            ResaleMatch.resale_matches_with_broker_clients(
              logged_in_user_id,
              broker_user_id
            )

        total_posts = posts |> length

        posts =
          posts
          |> Enum.sort_by(
            fn %{post_in_context: pic} -> pic.inserted_at end,
            &>=/2
          )
          |> Enum.slice(((page - 1) * @post_per_page)..(page * @post_per_page - 1))

        has_more_posts = page < Float.ceil(total_posts / @post_per_page)
        {:ok, posts, has_more_posts}
    end
  end

  def outstanding_matches_with_phone_number(
        logged_in_user_id,
        phone_number,
        country_code,
        page
      ) do
    case Credential.fetch_credential(phone_number, country_code) do
      nil ->
        {:ok, %{rows: []}}

      credential ->
        broker_user_id = credential.id

        posts =
          RentalMatch.rental_outstanding_matches_with_broker_properties(
            logged_in_user_id,
            broker_user_id
          ) ++
            RentalMatch.rental_outstanding_matches_with_broker_clients(
              logged_in_user_id,
              broker_user_id
            ) ++
            ResaleMatch.resale_outstanding_matches_with_broker_properties(
              logged_in_user_id,
              broker_user_id
            ) ++
            ResaleMatch.resale_outstanding_matches_with_broker_clients(
              logged_in_user_id,
              broker_user_id
            )

        total_posts = posts |> length

        posts =
          posts
          |> Enum.sort_by(
            fn %{post_in_context: pic} -> pic.inserted_at end,
            &>=/2
          )
          |> Enum.slice(((page - 1) * @post_per_page)..(page * @post_per_page - 1))

        has_more_posts = page < Float.ceil(total_posts / @post_per_page)
        {:ok, posts, has_more_posts}
    end
  end

  def all_outstanding_matches(logged_in_user_id, page) do
    posts =
      RentalMatch.rental_all_outstanding_matches_with_user_properties(logged_in_user_id) ++
        RentalMatch.rental_all_outstanding_matches_with_user_clients(logged_in_user_id) ++
        ResaleMatch.resale_all_outstanding_matches_with_user_properties(logged_in_user_id) ++
        ResaleMatch.resale_all_outstanding_matches_with_user_clients(logged_in_user_id)

    total_posts = posts |> length

    posts =
      posts
      |> Enum.sort_by(fn %{post_in_context: pic} -> pic.inserted_at end, &>=/2)
      |> Enum.slice(((page - 1) * @temp_post_per_page)..(page * @temp_post_per_page - 1))

    has_more_posts = page < Float.ceil(total_posts / @temp_post_per_page)
    {:ok, posts, has_more_posts, total_posts}
  end

  def all_read_matches(logged_in_user_id, page) do
    posts =
      RentalMatch.rental_all_read_matches_with_user_properties(logged_in_user_id) ++
        RentalMatch.rental_all_read_matches_with_user_clients(logged_in_user_id) ++
        ResaleMatch.resale_all_read_matches_with_user_properties(logged_in_user_id) ++
        ResaleMatch.resale_all_read_matches_with_user_clients(logged_in_user_id)

    total_posts = posts |> length

    posts =
      posts
      |> Enum.sort_by(
        fn %{post_in_context: pic} -> {pic.call_log_time} end,
        &>=/2
      )
      |> Enum.slice(((page - 1) * @post_per_page)..(page * @post_per_page - 1))

    has_more_posts = page < Float.ceil(total_posts / @post_per_page)
    {:ok, posts, has_more_posts}
  end

  def all_already_contacted_matches(logged_in_user_id, page) do
    posts =
      RentalMatch.rental_all_contacted_matches_with_user_properties(logged_in_user_id) ++
        RentalMatch.rental_all_contacted_matches_with_user_clients(logged_in_user_id) ++
        ResaleMatch.resale_all_contacted_matches_with_user_properties(logged_in_user_id) ++
        ResaleMatch.resale_all_contacted_matches_with_user_clients(logged_in_user_id)

    total_posts = posts |> length

    posts =
      posts
      |> Enum.sort_by(fn %{post_in_context: pic} -> pic.inserted_at end, &>=/2)
      |> Enum.slice(((page - 1) * @post_per_page)..(page * @post_per_page - 1))

    has_more_posts = page < Float.ceil(total_posts / @post_per_page)
    {:ok, posts, has_more_posts}
  end

  def outsider_profile_details(logged_in_user_id, broker_uuid, page)
      when page == 1 do
    with broker_credential = Accounts.get_credential_by_uuid(broker_uuid),
         call_logs_with_broker =
           CallLogs.call_logs_with_broker(
             logged_in_user_id,
             broker_credential.phone_number
           ),
         blocked =
           BnApis.Accounts.BlockedUser.is_blocked?(
             logged_in_user_id,
             broker_credential.id
           ),
         {:ok, posts, has_more_posts} <-
           fetch_all_matches_with_broker(logged_in_user_id, broker_uuid, page) do
      {:ok, posts, has_more_posts, blocked, broker_credential, call_logs_with_broker}
    end
  end

  def outsider_profile_details(logged_in_user_id, broker_uuid, page) do
    with {:ok, posts, has_more_posts} <-
           fetch_all_matches_with_broker(logged_in_user_id, broker_uuid, page),
         broker_credential = Accounts.get_credential_by_uuid(broker_uuid),
         blocked =
           BnApis.Accounts.BlockedUser.is_blocked?(
             logged_in_user_id,
             broker_credential.id
           ) do
      {:ok, posts, has_more_posts, blocked, nil, nil}
    end
  end

  def assign_all_posts_to_me(user_id, logged_user_id) do
    RentalMatch.assign_all_posts_to_me(user_id, logged_user_id)
    ResaleMatch.assign_all_posts_to_me(user_id, logged_user_id)
  end

  @doc """
  Marks all matches read for given user_id and phone_number
  """
  def mark_matches_read(user_id, call_log) do
    case Accounts.get_active_credential_by_phone(call_log.phone_number, call_log.country_code) do
      nil ->
        IO.puts("Cannot find user with given number!")

      other_party_cred ->
        RentalMatch.mark_matches_against_each_other_as_read(
          user_id,
          other_party_cred.id,
          call_log.id
        )

        ResaleMatch.mark_matches_against_each_other_as_read(
          user_id,
          other_party_cred.id,
          call_log.id
        )
    end
  end

  alias BnApis.Posts.RentalPropertyPost

  @doc """
  Gets a single rental_property_post.

  Raises `Ecto.NoResultsError` if the Rental property post does not exist.

  ## Examples

      iex> get_rental_property_post!(123)
      %RentalPropertyPost{}

      iex> get_rental_property_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rental_property_post!(id), do: Repo.get!(RentalPropertyPost, id)

  @doc """
  Creates a rental_property_post.

  ## Examples

      iex> create_rental_property_post(%{field: value})
      {:ok, %RentalPropertyPost{}}

      iex> create_rental_property_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rental_property_post(attrs \\ %{}) do
    %RentalPropertyPost{}
    |> RentalPropertyPost.changeset(attrs)
    |> Repo.insert()
  end

  alias BnApis.Posts.RentalClientPost

  @doc """
  Gets a single rental_client_post.

  Raises `Ecto.NoResultsError` if the Rental client post does not exist.

  ## Examples

      iex> get_rental_client_post!(123)
      %RentalClientPost{}

      iex> get_rental_client_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rental_client_post!(id), do: Repo.get!(RentalClientPost, id)

  @doc """
  Creates a rental_client_post.

  ## Examples

      iex> create_rental_client_post(%{field: value})
      {:ok, %RentalClientPost{}}

      iex> create_rental_client_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rental_client_post(attrs \\ %{}) do
    %RentalClientPost{}
    |> RentalClientPost.changeset(attrs)
    |> Repo.insert()
  end

  alias BnApis.Posts.ResalePropertyPost

  @doc """
  Gets a single resale_property_post.

  Raises `Ecto.NoResultsError` if the Resale property post does not exist.

  ## Examples

      iex> get_resale_property_post!(123)
      %ResalePropertyPost{}

      iex> get_resale_property_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_resale_property_post!(id), do: Repo.get!(ResalePropertyPost, id)

  @doc """
  Creates a resale_property_post.

  ## Examples

      iex> create_resale_property_post(%{field: value})
      {:ok, %ResalePropertyPost{}}

      iex> create_resale_property_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_resale_property_post(attrs \\ %{}) do
    %ResalePropertyPost{}
    |> ResalePropertyPost.changeset(attrs)
    |> Repo.insert()
  end

  alias BnApis.Posts.ResaleClientPost

  @doc """
  Gets a single resale_client_post.

  Raises `Ecto.NoResultsError` if the Resale client post does not exist.

  ## Examples

      iex> get_resale_client_post!(123)
      %ResaleClientPost{}

      iex> get_resale_client_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_resale_client_post!(id), do: Repo.get!(ResaleClientPost, id)

  @doc """
  Creates a resale_client_post.

  ## Examples

      iex> create_resale_client_post(%{field: value})
      {:ok, %ResaleClientPost{}}

      iex> create_resale_client_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_resale_client_post(attrs \\ %{}) do
    %ResaleClientPost{}
    |> ResaleClientPost.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
    1. Fetches last property post associated with user which got auto expired on given date
  """
  def fetch_expired_property_post(user_id, datetime) do
    rental_property_post =
      RentalPropertyPost
      |> where(
        [rpp],
        rpp.assigned_user_id == ^user_id and rpp.expires_in == ^datetime
      )
      |> where([rpp], rpp.archived == false and is_nil(rpp.refreshed_by_id))
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> Repo.one()

    resale_property_post =
      ResalePropertyPost
      |> where(
        [rpp],
        rpp.assigned_user_id == ^user_id and rpp.expires_in == ^datetime
      )
      |> where([rpp], rpp.archived == false and is_nil(rpp.refreshed_by_id))
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> Repo.one()

    [rental_property_post, resale_property_post] |> Enum.reject(&is_nil(&1))
  end

  @doc """
    1. Fetches last client post associated with user which got auto expired on given date
  """
  def fetch_expired_client_post(user_id, datetime) do
    rental_client_post =
      RentalClientPost
      |> where(
        [rcp],
        rcp.assigned_user_id == ^user_id and rcp.expires_in == ^datetime
      )
      |> where([rcp], rcp.archived == false and is_nil(rcp.refreshed_by_id))
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> Repo.one()

    resale_client_post =
      ResaleClientPost
      |> where(
        [rcp],
        rcp.assigned_user_id == ^user_id and rcp.expires_in == ^datetime
      )
      |> where([rcp], rcp.archived == false and is_nil(rcp.refreshed_by_id))
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> Repo.one()

    [rental_client_post, resale_client_post] |> Enum.reject(&is_nil(&1))
  end

  def fetch_latest_property_post_query(user_id) do
    rental_property_post =
      RentalPropertyPost
      |> where(assigned_user_id: ^user_id)
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> Repo.one()

    first_time =
      case rental_property_post do
        nil -> nil
        rcp -> rcp.inserted_at |> Time.naive_to_epoch()
      end

    resale_property_post =
      ResalePropertyPost
      |> where(assigned_user_id: ^user_id)
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> Repo.one()

    second_time =
      case resale_property_post do
        nil -> nil
        rcp -> rcp.inserted_at |> Time.naive_to_epoch()
      end

    list = [first_time, second_time] |> Enum.reject(&is_nil/1)

    case list |> length do
      0 -> nil
      _ -> list |> Enum.max()
    end
  end

  def fetch_latest_client_post_query(user_id) do
    rental_client_post =
      RentalClientPost
      |> where(assigned_user_id: ^user_id)
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> Repo.one()

    first_time =
      case rental_client_post do
        nil -> nil
        rcp -> rcp.inserted_at |> Time.naive_to_epoch()
      end

    resale_client_post =
      ResaleClientPost
      |> where(assigned_user_id: ^user_id)
      |> order_by(desc: :inserted_at)
      |> limit(1)
      |> Repo.one()

    second_time =
      case resale_client_post do
        nil -> nil
        rcp -> rcp.inserted_at |> Time.naive_to_epoch()
      end

    list = [first_time, second_time] |> Enum.reject(&is_nil/1)

    case list |> length do
      0 -> nil
      _ -> list |> Enum.max()
    end
  end

  def fetch_last_repost_property_post_query(user_id) do
    rental_property_post =
      RentalPropertyPost
      |> where([rpp], rpp.assigned_user_id == ^user_id)
      |> where([rpp], not is_nil(rpp.updation_time))
      |> order_by(desc: :updation_time)
      |> limit(1)
      |> Repo.one()

    first_time =
      case rental_property_post do
        nil -> nil
        rpp -> rpp.updation_time |> Time.naive_to_epoch()
      end

    resale_property_post =
      ResalePropertyPost
      |> where([rpp], rpp.assigned_user_id == ^user_id)
      |> where([rpp], not is_nil(rpp.updation_time))
      |> order_by(desc: :updation_time)
      |> limit(1)
      |> Repo.one()

    second_time =
      case resale_property_post do
        nil -> nil
        rpp -> rpp.updation_time |> Time.naive_to_epoch()
      end

    list = [first_time, second_time] |> Enum.reject(&is_nil/1)

    case list |> length do
      0 -> nil
      _ -> list |> Enum.max()
    end
  end

  def fetch_last_repost_client_post_query(user_id) do
    rental_client_post =
      RentalClientPost
      |> where([rcp], rcp.assigned_user_id == ^user_id)
      |> where([rcp], not is_nil(rcp.updation_time))
      |> order_by(desc: :updation_time)
      |> limit(1)
      |> Repo.one()

    first_time =
      case rental_client_post do
        nil -> nil
        rcp -> rcp.updation_time |> Time.naive_to_epoch()
      end

    resale_client_post =
      ResaleClientPost
      |> where([rcp], rcp.assigned_user_id == ^user_id)
      |> where([rcp], not is_nil(rcp.updation_time))
      |> order_by(desc: :updation_time)
      |> limit(1)
      |> Repo.one()

    second_time =
      case resale_client_post do
        nil -> nil
        rcp -> rcp.updation_time |> Time.naive_to_epoch()
      end

    list = [first_time, second_time] |> Enum.reject(&is_nil/1)

    case list |> length do
      0 -> nil
      _ -> list |> Enum.max()
    end
  end

  def fetch_latest_outstanding_match_date(broker_id) do
    dates =
      [
        RentalMatch.latest_outstanding_rental_client_match_date(broker_id),
        RentalMatch.latest_outstanding_rental_property_match_date(broker_id),
        ResaleMatch.latest_outstanding_resale_client_match_date(broker_id),
        ResaleMatch.latest_outstanding_resale_property_match_date(broker_id)
      ]
      |> Enum.reject(&is_nil/1)

    case dates |> length do
      0 -> nil
      _ -> dates |> Enum.max()
    end
  end

  def fetch_latest_match_date(broker_id) do
    dates =
      [
        RentalMatch.latest_rental_client_match_date(broker_id),
        RentalMatch.latest_rental_property_match_date(broker_id),
        ResaleMatch.latest_resale_client_match_date(broker_id),
        ResaleMatch.latest_resale_property_match_date(broker_id)
      ]
      |> Enum.reject(&is_nil/1)

    case dates |> length do
      0 -> nil
      _ -> dates |> Enum.max()
    end
  end

  alias BnApis.Posts.PostAssignmentHistory

  @doc """
  Returns the list of posts_assignment_history.

  ## Examples

      iex> list_posts_assignment_history()
      [%PostAssignmentHistory{}, ...]

  """
  def list_posts_assignment_history do
    Repo.all(PostAssignmentHistory)
  end

  @doc """
  Gets a single post_assignment_history.

  Raises `Ecto.NoResultsError` if the Post assignment history does not exist.

  ## Examples

      iex> get_post_assignment_history!(123)
      %PostAssignmentHistory{}

      iex> get_post_assignment_history!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post_assignment_history!(id), do: Repo.get!(PostAssignmentHistory, id)

  @doc """
  Creates a post_assignment_history.

  ## Examples

      iex> create_post_assignment_history(%{field: value})
      {:ok, %PostAssignmentHistory{}}

      iex> create_post_assignment_history(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post_assignment_history(attrs \\ %{}) do
    %PostAssignmentHistory{}
    |> PostAssignmentHistory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a post_assignment_history.

  ## Examples

      iex> update_post_assignment_history(post_assignment_history, %{field: new_value})
      {:ok, %PostAssignmentHistory{}}

      iex> update_post_assignment_history(post_assignment_history, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post_assignment_history(
        %PostAssignmentHistory{} = post_assignment_history,
        attrs
      ) do
    post_assignment_history
    |> PostAssignmentHistory.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a PostAssignmentHistory.

  ## Examples

      iex> delete_post_assignment_history(post_assignment_history)
      {:ok, %PostAssignmentHistory{}}

      iex> delete_post_assignment_history(post_assignment_history)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post_assignment_history(%PostAssignmentHistory{} = post_assignment_history) do
    Repo.delete(post_assignment_history)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post_assignment_history changes.

  ## Examples

      iex> change_post_assignment_history(post_assignment_history)
      %Ecto.Changeset{source: %PostAssignmentHistory{}}

  """
  def change_post_assignment_history(%PostAssignmentHistory{} = post_assignment_history) do
    PostAssignmentHistory.changeset(post_assignment_history, %{})
  end

  def assigned_posts_count(user_id) do
    ren_client_count =
      RentalClientPost
      |> where([p], p.assigned_user_id == ^user_id and p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> BnApis.Repo.aggregate(:count, :id)

    ren_property_count =
      RentalPropertyPost
      |> where([p], p.assigned_user_id == ^user_id and p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> BnApis.Repo.aggregate(:count, :id)

    res_property_count =
      ResalePropertyPost
      |> where([p], p.assigned_user_id == ^user_id and p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> BnApis.Repo.aggregate(:count, :id)

    res_client_count =
      ResaleClientPost
      |> where([p], p.assigned_user_id == ^user_id and p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> BnApis.Repo.aggregate(:count, :id)

    ren_client_count + ren_property_count + res_property_count +
      res_client_count
  end

  def posts_count(start_datetime, end_datetime \\ NaiveDateTime.utc_now()) do
    start_datetime_filter = is_nil(start_datetime)

    ren_client_count =
      RentalClientPost
      |> where([p], p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> where([p], p.inserted_at <= ^end_datetime)
      |> where(
        [p],
        fragment(
          "? or ? >= ?",
          ^start_datetime_filter,
          p.inserted_at,
          ^start_datetime
        )
      )
      |> BnApis.Repo.aggregate(:count, :id)

    ren_property_count =
      RentalPropertyPost
      |> where([p], p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> where([p], p.inserted_at <= ^end_datetime)
      |> where(
        [p],
        fragment(
          "? or ? >= ?",
          ^start_datetime_filter,
          p.inserted_at,
          ^start_datetime
        )
      )
      |> BnApis.Repo.aggregate(:count, :id)

    res_property_count =
      ResalePropertyPost
      |> where([p], p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> where([p], p.inserted_at <= ^end_datetime)
      |> where(
        [p],
        fragment(
          "? or ? >= ?",
          ^start_datetime_filter,
          p.inserted_at,
          ^start_datetime
        )
      )
      |> BnApis.Repo.aggregate(:count, :id)

    res_client_count =
      ResaleClientPost
      |> where([p], p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> where([p], p.inserted_at <= ^end_datetime)
      |> where(
        [p],
        fragment(
          "? or ? >= ?",
          ^start_datetime_filter,
          p.inserted_at,
          ^start_datetime
        )
      )
      |> BnApis.Repo.aggregate(:count, :id)

    %{
      clients: ren_client_count + res_client_count,
      properties: res_property_count + ren_property_count
    }
  end

  def assigned_posts_count_for_brokers(broker_ids) do
    credential_ids = Repo.all(from c in Credential, where: c.broker_id in ^broker_ids, select: c.id)

    ren_client_count =
      RentalClientPost
      |> where([p], p.assigned_user_id in ^credential_ids)
      |> where([p], p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> BnApis.Repo.aggregate(:count, :id)

    ren_property_count =
      RentalPropertyPost
      |> where([p], p.assigned_user_id in ^credential_ids)
      |> where([p], p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> BnApis.Repo.aggregate(:count, :id)

    res_property_count =
      ResalePropertyPost
      |> where([p], p.assigned_user_id in ^credential_ids)
      |> where([p], p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> BnApis.Repo.aggregate(:count, :id)

    res_client_count =
      ResaleClientPost
      |> where([p], p.assigned_user_id in ^credential_ids)
      |> where([p], p.archived == false)
      |> where([p], fragment("? >= timezone('utc', NOW())", p.expires_in))
      |> BnApis.Repo.aggregate(:count, :id)

    ren_client_count + ren_property_count + res_property_count +
      res_client_count
  end

  def matches_count(start_datetime, end_datetime \\ NaiveDateTime.utc_now()) do
    start_datetime_filter = start_datetime |> is_nil()

    rental_match_count =
      RentalMatch
      |> distinct(true)
      |> join(
        :inner,
        [rm],
        rcp in RentalClientPost,
        on: rcp.id == rm.rental_client_id
      )
      |> join(
        :inner,
        [rm, rcp],
        rpp in RentalPropertyPost,
        on: rpp.id == rm.rental_property_id
      )
      |> where([rm, rcp, rpp], rcp.archived == false and rpp.archived == false)
      |> where(
        [rm, rcp, rpp],
        fragment("? >= timezone('utc', NOW())", rcp.expires_in) and
          fragment("? >= timezone('utc', NOW())", rpp.expires_in)
      )
      |> where([rm, _, _], rm.inserted_at <= ^end_datetime)
      |> where(
        [rm, _, _],
        fragment(
          "? or ? >= ?",
          ^start_datetime_filter,
          rm.inserted_at,
          ^start_datetime
        )
      )
      |> BnApis.Repo.aggregate(:count, :id)

    resale_match_count =
      ResaleMatch
      |> distinct(true)
      |> join(
        :inner,
        [rm],
        rcp in ResaleClientPost,
        on: rcp.id == rm.resale_client_id
      )
      |> join(
        :inner,
        [rm, rcp],
        rpp in ResalePropertyPost,
        on: rpp.id == rm.resale_property_id
      )
      |> where([rm, rcp, rpp], rcp.archived == false and rpp.archived == false)
      |> where(
        [rm, rcp, rpp],
        fragment("? >= timezone('utc', NOW())", rcp.expires_in) and
          fragment("? >= timezone('utc', NOW())", rpp.expires_in)
      )
      |> where([rm, _, _], rm.inserted_at <= ^end_datetime)
      |> where(
        [rm, _, _],
        fragment(
          "? or ? >= ?",
          ^start_datetime_filter,
          rm.inserted_at,
          ^start_datetime
        )
      )
      |> BnApis.Repo.aggregate(:count, :id)

    rental_match_count + resale_match_count
  end

  def get_expired_posts_count(user_id, datetime) do
    rental_client_posts =
      RentalClientPost
      |> where([rcp], rcp.assigned_user_id == ^user_id)
      |> where([rcp], rcp.expires_in == ^datetime)
      |> where([rcp], rcp.archived == false and is_nil(rcp.refreshed_by_id))
      |> BnApis.Repo.aggregate(:count, :id)

    rental_property_posts =
      RentalPropertyPost
      |> where([rpp], rpp.assigned_user_id == ^user_id)
      |> where([rpp], rpp.expires_in == ^datetime)
      |> where([rpp], rpp.archived == false and is_nil(rpp.refreshed_by_id))
      |> BnApis.Repo.aggregate(:count, :id)

    resale_client_posts =
      ResaleClientPost
      |> where([rcp], rcp.assigned_user_id == ^user_id)
      |> where([rcp], rcp.expires_in == ^datetime)
      |> where([rcp], rcp.archived == false and is_nil(rcp.refreshed_by_id))
      |> BnApis.Repo.aggregate(:count, :id)

    resale_property_posts =
      ResalePropertyPost
      |> where([rpp], rpp.assigned_user_id == ^user_id)
      |> where([rpp], rpp.expires_in == ^datetime)
      |> where([rpp], rpp.archived == false and is_nil(rpp.refreshed_by_id))
      |> BnApis.Repo.aggregate(:count, :id)

    rental_client_posts + rental_property_posts + resale_client_posts +
      resale_property_posts
  end

  def post_info(configuration_type_ids, building_ids) do
    config_names =
      configuration_type_ids
      |> Enum.map(&ConfigurationType.get_by_id(&1).name)
      |> Enum.join("/")
      |> String.replace(" BHK", "")
      |> BnApisWeb.PostView.return_config_name()

    building_names =
      building_ids
      |> BnApis.Buildings.Building.get_building_names()
      |> Enum.join(", ")

    "#{config_names} in #{building_names} "
  end

  def get_last_post_days(credential) do
    latest_property_post_date = fetch_latest_property_post_query(credential.id)
    latest_client_post_date = fetch_latest_client_post_query(credential.id)

    last_property_repost_date = fetch_last_repost_property_post_query(credential.id)

    last_client_repost_date = fetch_last_repost_client_post_query(credential.id)

    list =
      [
        latest_client_post_date,
        latest_property_post_date,
        last_property_repost_date,
        last_client_repost_date
      ]
      |> Enum.reject(&is_nil/1)

    if List.first(list) |> is_nil() do
      nil
    else
      latest_post_date = list |> Enum.max()
      latest_post_date = latest_post_date |> Time.epoch_to_naive()
      now = NaiveDateTime.utc_now()

      (NaiveDateTime.diff(now, latest_post_date, :second) / (60 * 60 * 24))
      |> round
    end
  end

  def fetch_owner_posts_polygon_distribution(params) do
    city_id = (params["city_id"] && params["city_id"] |> String.to_integer()) || 37
    sort_by = "all_paid_brokers_with_active_subs_count"

    rental_base_query =
      RentalPropertyPost
      |> join(:inner, [rpp], b in Building, on: rpp.building_id == b.id)
      |> where([rpp], rpp.uploader_type == @owner)

    rental_base_query =
      if not is_nil(params["is_verified"]) do
        rental_base_query |> where([r], r.is_verified == ^params["is_verified"])
      else
        rental_base_query
      end

    all_rental_active_properties =
      rental_base_query
      |> where([rpp], rpp.archived == false)
      |> select(
        [rpp, b],
        {b.polygon_id, rpp.id, fragment("ROUND(extract(epoch from ?))::int", rpp.inserted_at), fragment("ROUND(extract(epoch from ?))::int", rpp.last_refreshed_at)}
      )
      |> Repo.all()

    rental_post_live_today = get_post_live_count_by_polygon(all_rental_active_properties, Time.today())
    rental_post_live_this_week = get_post_live_count_by_polygon(all_rental_active_properties, Time.this_week())
    rental_post_live_this_month = get_post_live_count_by_polygon(all_rental_active_properties, Time.this_month())

    resale_base_query =
      ResalePropertyPost
      |> join(:inner, [rpp], b in Building, on: rpp.building_id == b.id)
      |> where([rpp], rpp.uploader_type == @owner)

    resale_base_query =
      if not is_nil(params["is_verified"]) do
        resale_base_query |> where([r], r.is_verified == ^params["is_verified"])
      else
        resale_base_query
      end

    all_resale_active_properties =
      resale_base_query
      |> where([rpp], rpp.archived == false)
      |> select(
        [rpp, b],
        {b.polygon_id, rpp.id, fragment("ROUND(extract(epoch from ?))::int", rpp.inserted_at), fragment("ROUND(extract(epoch from ?))::int", rpp.last_refreshed_at)}
      )
      |> Repo.all()

    resale_post_live_today = get_post_live_count_by_polygon(all_resale_active_properties, Time.today())
    resale_post_live_this_week = get_post_live_count_by_polygon(all_resale_active_properties, Time.this_week())
    resale_post_live_this_month = get_post_live_count_by_polygon(all_resale_active_properties, Time.this_month())

    reported_resale_polygon_distribution =
      ReportedResalePropertyPost
      |> where([rpo], is_nil(rpo.refreshed_by_id))
      |> join(:inner, [rpo], po in ResalePropertyPost, on: rpo.resale_property_id == po.id)
      |> join(:inner, [rpo, po], b in Building, on: po.building_id == b.id)
      |> where([rpo, po], po.archived == false)
      |> select([rpo, po, b], {b.polygon_id, po.id})
      |> Repo.all()
      |> Enum.uniq()
      |> Enum.group_by(fn {x, _} -> x end)
      |> Enum.map(fn {key, val} -> {key, length(val)} end)
      |> Enum.into(%{})

    reported_rental_polygon_distribution =
      ReportedRentalPropertyPost
      |> where([rpo], is_nil(rpo.refreshed_by_id))
      |> join(:inner, [rpo], po in RentalPropertyPost, on: rpo.rental_property_id == po.id)
      |> where([rpo, po], po.archived == false)
      |> join(:inner, [rpo, po], b in Building, on: po.building_id == b.id)
      |> select([rpo, po, b], {b.polygon_id, po.id})
      |> Repo.all()
      |> Enum.uniq()
      |> Enum.group_by(fn {x, _} -> x end)
      |> Enum.map(fn {key, val} -> {key, length(val)} end)
      |> Enum.into(%{})

    all_active_brokers_with_polygon_details =
      Broker
      |> join(:inner, [b], c in Credential, on: c.broker_id == b.id)
      |> where([b, c], not is_nil(c.app_version))
      |> select([b, c], {b.id, b.polygon_id})
      |> Repo.all()

    all_active_brokers =
      all_active_brokers_with_polygon_details
      |> Enum.group_by(fn {_, y} -> y end)
      |> Enum.map(fn {key, val} -> {key, length(val)} end)
      |> Enum.into(%{})

    # Only active broker list is considered
    all_paytm_paid_brokers_with_polygon_detail =
      MatchPlusMembership
      |> join(:inner, [m], b in Broker, on: m.broker_id == b.id)
      |> join(:inner, [m, b], c in Credential, on: c.broker_id == b.id)
      |> where([m, b, c], not is_nil(c.app_version))
      |> select([m, b, c], {b.id, b.polygon_id, m.status_id})
      |> Repo.all()

    all_paytm_paid_brokers =
      Enum.map(all_paytm_paid_brokers_with_polygon_detail, fn x -> {elem(x, 1), elem(x, 2)} end)
      |> Enum.group_by(fn {x, y} -> {x, y} end)
      |> Enum.map(fn {key, val} -> {elem(key, 0), elem(key, 1), length(val)} end)
      |> Enum.reduce(%{}, fn tp, acc ->
        map = Map.get(acc, elem(tp, 0), %{})
        map_count = map[elem(tp, 1)] || 0 + elem(tp, 2)
        map = Map.put(map, elem(tp, 1), map_count)
        Map.put(acc, elem(tp, 0), map)
      end)

    # Only active broker list is considered
    all_razorpay_paid_brokers_with_polygon_detail =
      MatchPlus
      |> join(:inner, [m], b in Broker, on: m.broker_id == b.id)
      |> join(:inner, [m, b], c in Credential, on: c.broker_id == b.id)
      |> where([m, b, c], not is_nil(c.app_version))
      |> select([m, b, c], {b.id, b.polygon_id, m.status_id})
      |> Repo.all()

    all_razorpay_paid_brokers =
      Enum.map(all_razorpay_paid_brokers_with_polygon_detail, fn x -> {elem(x, 1), elem(x, 2)} end)
      |> Enum.group_by(fn {x, y} -> {x, y} end)
      |> Enum.map(fn {key, val} -> {elem(key, 0), elem(key, 1), length(val)} end)
      |> Enum.reduce(%{}, fn tp, acc ->
        map = Map.get(acc, elem(tp, 0), %{})
        map_count = map[elem(tp, 1)] || 0 + elem(tp, 2)
        map = Map.put(map, elem(tp, 1), map_count)
        Map.put(acc, elem(tp, 0), map)
      end)

    all_paid_brokers_ids =
      MapSet.new(
        Enum.map(all_paytm_paid_brokers_with_polygon_detail, fn x -> elem(x, 0) end) ++
          Enum.map(all_razorpay_paid_brokers_with_polygon_detail, fn x -> elem(x, 0) end)
      )

    active_earlier_inactive_now_brokers = %{}
    # Broker
    # |> where([b], b.is_match_enabled == ^true)
    # |> group_by([b], b.polygon_id)
    # |> select([m, b], {b.polygon_id, count(b.id)})
    # |> Repo.all()
    # |> Enum.reduce(%{}, fn tp, acc ->
    #   Map.put(acc, elem(tp, 0), elem(tp, 1))
    # end)

    all_active_brokers_who_never_subscribed = Enum.filter(all_active_brokers_with_polygon_details, fn x -> not MapSet.member?(all_paid_brokers_ids, elem(x, 0)) end)

    # Only active broker list is considered
    all_brokers_who_never_subscribed =
      Enum.uniq(all_active_brokers_who_never_subscribed)
      |> Enum.group_by(fn {_, y} -> y end)
      |> Enum.map(fn {x, y} -> {x, length(y)} end)
      |> Enum.into(%{})

    all_rental_polygon_distribution =
      rental_base_query
      |> group_by([rpp, b], [rpp.archived, b.polygon_id])
      |> select([rpp, b], {b.polygon_id, rpp.archived, count(rpp.id)})
      |> Repo.all()
      |> Enum.reduce(%{}, fn tp, acc ->
        map = Map.get(acc, elem(tp, 0), %{})
        map_count = map[elem(tp, 1)] || 0 + elem(tp, 2)
        map = Map.put(map, elem(tp, 1), map_count)
        Map.put(acc, elem(tp, 0), map)
      end)

    all_resale_polygon_distribution =
      resale_base_query
      |> group_by([rpp, b], [rpp.archived, b.polygon_id])
      |> select([rpp, b], {b.polygon_id, rpp.archived, count(rpp.id)})
      |> Repo.all()
      |> Enum.reduce(%{}, fn tp, acc ->
        map = Map.get(acc, elem(tp, 0), %{})
        map_count = map[elem(tp, 1)] || 0 + elem(tp, 2)
        map = Map.put(map, elem(tp, 1), map_count)
        Map.put(acc, elem(tp, 0), map)
      end)

    polygons =
      Polygon
      |> where([p], p.city_id == ^city_id)
      |> Repo.all()
      |> Enum.map(fn poly ->
        paytm_paid_broker_map = all_paytm_paid_brokers[poly.id] || %{}
        razorpay_paid_brokers = all_razorpay_paid_brokers[poly.id] || %{}

        %{
          id: poly.id,
          name: poly.name,
          city_id: poly.city_id,
          rental_live_count: all_rental_polygon_distribution[poly.id][false] || 0,
          rental_post_live_today: rental_post_live_today[poly.id] || 0,
          rental_post_live_this_week: rental_post_live_this_week[poly.id] || 0,
          rental_post_live_this_month: rental_post_live_this_month[poly.id] || 0,
          resale_live_count: all_resale_polygon_distribution[poly.id][false] || 0,
          resale_post_live_today: resale_post_live_today[poly.id] || 0,
          resale_post_live_this_week: resale_post_live_this_week[poly.id] || 0,
          resale_post_live_this_month: resale_post_live_this_month[poly.id] || 0,
          rental_archive_count: all_rental_polygon_distribution[poly.id][true] || 0,
          resale_archive_count: all_resale_polygon_distribution[poly.id][true] || 0,
          reported_rental_count: reported_rental_polygon_distribution[poly.id] || 0,
          reported_resale_count: reported_resale_polygon_distribution[poly.id] || 0,
          all_active_brokers_count: all_active_brokers[poly.id] || 0,
          all_paytm_paid_active_brokers_count: paytm_paid_broker_map[MatchPlus.get_active_status_id()] || 0,
          all_razorpay_paid_active_brokers_count: razorpay_paid_brokers[MatchPlus.get_active_status_id()] || 0,
          all_paid_brokers_until_now_count:
            (Enum.reduce(paytm_paid_broker_map, 0, fn {_k, v}, acc -> acc + v end) || 0) +
              (Enum.reduce(razorpay_paid_brokers, 0, fn {_k, v}, acc -> acc + v end) || 0),
          all_paid_brokers_with_active_subs_count: (paytm_paid_broker_map[MatchPlus.get_active_status_id()] || 0) + (razorpay_paid_brokers[MatchPlus.get_active_status_id()] || 0),
          active_earlier_inactive_now_brokers: active_earlier_inactive_now_brokers[poly.id] || 0,
          all_brokers_who_never_subscribed: all_brokers_who_never_subscribed[poly.id] || 0
        }
      end)

    polygons =
      if sort_by == "all_paid_brokers_with_active_subs_count",
        do: polygons |> Enum.sort(&(&1.all_paid_brokers_with_active_subs_count > &2.all_paid_brokers_with_active_subs_count)),
        else: polygons

    polygons
  end

  def get_post_live_count_by_polygon(posts, time_range_query) do
    {start_time, end_time} = Time.get_time_range(time_range_query)

    Enum.filter(posts, fn post ->
      (start_time <= elem(post, 2) and end_time >= elem(post, 2)) or
        (start_time <= elem(post, 3) and end_time >= elem(post, 3))
    end)
    |> Enum.group_by(fn {x, _, _, _} -> x end)
    |> Enum.map(fn {key, val} -> {key, length(val)} end)
    |> Enum.into(%{})
  end

  defp hide_owner_info_for_assisted_posts(posts) do
    posts
    |> Enum.map(fn post ->
      post =
        if post[:is_assisted] == true do
          post
          |> Map.put(:assigned_owner, %{})
        else
          post
        end

      post
    end)
  end

  defp mask_owner_info_in_matches_home_posts(posts, lock_posts) do
    posts
    |> Enum.map(fn post ->
      post |> Map.put(:matches, mask_owner_info_in_posts(post[:matches], lock_posts))
    end)
  end

  defp hide_owner_info_in_matches_home_posts(posts) do
    posts
    |> Enum.map(fn post ->
      post |> Map.put(:matches, hide_owner_info_for_assisted_posts(post[:matches]))
    end)
  end

  def mask_owner_info_in_posts(posts, lock_posts \\ true) do
    posts
    |> Enum.map(fn post ->
      post =
        if post[:uploader_type] == @owner and lock_posts do
          post
          |> Map.put(:is_unlocked, false)
          |> Map.put(:assigned_owner, %{
            country_code: "xxx",
            email: "xxxxxxxx@xxxxxx.xxx",
            id: 0,
            name: "xxxxxxxx",
            phone_number: "xxxxxxxxxx",
            uuid: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
          })
        else
          post |> Map.put(:is_unlocked, true)
        end

      post
    end)
  end

  defp mark_shortlisted_info_in_matches_home(posts, user_id) do
    broker = Accounts.get_broker_by_user_id(user_id)
    rental_post_uuids = broker.shortlisted_rental_posts |> Enum.map(& &1["uuid"])
    resale_post_uuids = broker.shortlisted_resale_posts |> Enum.map(& &1["uuid"])

    posts
    |> Enum.map(fn post ->
      post |> Map.put(:matches, mark_shortlisted_info_in_matches(post[:matches], rental_post_uuids, resale_post_uuids))
    end)
  end

  defp mark_shortlisted_info_in_matches(matches, user_id) do
    broker = Accounts.get_broker_by_user_id(user_id)
    rental_post_uuids = broker.shortlisted_rental_posts |> Enum.map(& &1["uuid"])
    resale_post_uuids = broker.shortlisted_resale_posts |> Enum.map(& &1["uuid"])
    mark_shortlisted_info_in_matches(matches, rental_post_uuids, resale_post_uuids)
  end

  defp mark_shortlisted_info_in_matches(matches, rental_post_uuids, resale_post_uuids) do
    matches
    |> Enum.map(fn match ->
      case match[:title] do
        "Rental Property" ->
          match |> Map.put(:is_shortlisted, Enum.member?(rental_post_uuids, match[:post_uuid]))

        "Resale Property" ->
          match |> Map.put(:is_shortlisted, Enum.member?(resale_post_uuids, match[:post_uuid]))

        _ ->
          match
      end
    end)
  end

  def handle_whatsapp_button_webhook(button_payload, owner_phone_number) do
    post_type = button_payload["post_type"]
    post_uuid = button_payload["post_uuid"]
    action = button_payload["action"]

    post_class =
      case post_type do
        @rent -> RentalPropertyPost
        @resale -> ResalePropertyPost
        _ -> nil
      end

    take_action_as_per_whatsapp_webhook(post_class, post_type, post_uuid, owner_phone_number, action)
  end

  def take_action_as_per_whatsapp_webhook(nil, _post_type, _post_uuid, _owner_phone_number, _action), do: nil

  def take_action_as_per_whatsapp_webhook(post_class, post_type, post_uuid, owner_phone_number, action)
      when action == "refresh" do
    whatsapp_employee_bot = WhatsappHelper.get_whatsapp_bot_employee_credential()

    refresh_owner_post(
      post_class,
      post_type,
      "property",
      whatsapp_employee_bot.id,
      post_uuid,
      whatsapp_employee_bot.employee_role_id,
      nil
    )

    auto_reply_to_whatsapp_button_response(post_type, owner_phone_number, action)
  end

  def take_action_as_per_whatsapp_webhook(post_class, post_type, post_uuid, owner_phone_number, action)
      when action == "deactivate" do
    whatsapp_employee_bot = WhatsappHelper.get_whatsapp_bot_employee_credential()

    archive_owner_post(
      post_class,
      post_type,
      "property",
      whatsapp_employee_bot.id,
      post_uuid,
      whatsapp_employee_bot.employee_role_id,
      @property_sold_out_reason_id
    )

    auto_reply_to_whatsapp_button_response(post_type, owner_phone_number, action)
  end

  def take_action_as_per_whatsapp_webhook(post_class, post_type, post_uuid, _owner_phone_number, action)
      when action == "verify" do
    whatsapp_employee_bot = WhatsappHelper.get_whatsapp_bot_employee_credential()
    verify_owner_post(post_class, post_type, whatsapp_employee_bot.id, post_uuid, whatsapp_employee_bot.employee_role_id)
    start_time_unix = Time.get_start_time_in_unix(-1)
    end_time_unix = Time.get_end_time_in_unix(-1)

    case post_type do
      @rent -> notify_brokers_to_contact_owner_post(RentalPropertyPost, ContactedRentalPropertyPost, post_uuid, start_time_unix, end_time_unix)
      @resale -> notify_brokers_to_contact_owner_post(ResalePropertyPost, ContactedResalePropertyPost, post_uuid, start_time_unix, end_time_unix)
    end
  end

  def auto_reply_to_whatsapp_button_response(@rent, owner_phone_number, "refresh") do
    Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      owner_phone_number,
      @rent_map.refresh_auto_reply_mssg_template
    ])
  end

  def auto_reply_to_whatsapp_button_response(@rent, owner_phone_number, "deactivate") do
    Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      owner_phone_number,
      @rent_map.archive_auto_reply_mssg_template
    ])
  end

  def auto_reply_to_whatsapp_button_response(@resale, owner_phone_number, "refresh") do
    Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      owner_phone_number,
      @resale_map.refresh_auto_reply_mssg_template
    ])
  end

  def auto_reply_to_whatsapp_button_response(@resale, owner_phone_number, "deactivate") do
    Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      owner_phone_number,
      @resale_map.archive_auto_reply_mssg_template
    ])
  end

  def send_referral_mssg_after_deactivating_posts(owner_phone_number, owner_name, @rent) do
    Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      owner_phone_number,
      @rent_map.referral_mssg_template,
      [owner_name]
    ])
  end

  def send_referral_mssg_after_deactivating_posts(nil, _owner_name, @resale), do: nil

  def send_referral_mssg_after_deactivating_posts(owner_phone_number, owner_name, @resale) do
    Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      owner_phone_number,
      @resale_map.referral_mssg_template,
      [owner_name]
    ])
  end

  def notify_brokers_to_contact_owner_post(post_class, contact_post_class, post_uuid, start_time_unix, end_time_unix) do
    post = Repo.get_by(post_class, uuid: post_uuid)

    broker_ids =
      contact_post_class
      |> where(
        [rp],
        rp.count == 0 and rp.post_id == ^post.id and
          ^start_time_unix <= fragment("ROUND(extract(epoch from ?))", rp.inserted_at) and
          ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", rp.inserted_at)
      )
      |> select([rp], rp.user_id)
      |> Repo.all()

    Credential
    |> where([c], c.broker_id in ^broker_ids and c.active == true and not is_nil(c.fcm_id))
    |> Repo.all()
    |> Enum.each(fn credential ->
      title = "New properties added today"
      message = "Explore Listings Now!"
      type = "NEW_OWNER_LISTINGS"
      data = %{"post_uuid" => post_uuid, "title" => title, "message" => message}

      Exq.enqueue(Exq, "send_owner_notifs", BnApis.Notifications.PushNotificationWorker, [
        credential.fcm_id,
        %{data: data, type: type},
        credential.id,
        credential.notification_platform
      ])

      Process.sleep(100)
    end)
  end

  def list_similar_posts_for_broker(@rent, post_uuid, user_id) do
    broker = Accounts.get_broker_by_user_id(user_id)

    posts =
      Repo.get_by(RentalPropertyPost, uuid: post_uuid)
      |> RentalPropertyPost.get_similar_posts_query(broker)
      |> Repo.all()
      |> Enum.map(fn post ->
        RentalPropertyPost.get_rental_post_details(post, broker)
      end)

    posts = RentalPropertyPost.add_contacted_details_for_broker(posts, broker)
    RentalPropertyPost.add_shortlisted_details_for_broker(posts, broker)
  end

  def list_similar_posts_for_broker(@resale, post_uuid, user_id) do
    broker = Accounts.get_broker_by_user_id(user_id)

    posts =
      Repo.get_by(ResalePropertyPost, uuid: post_uuid)
      |> ResalePropertyPost.get_similar_posts_query(broker)
      |> Repo.all()
      |> Enum.map(fn post ->
        ResalePropertyPost.get_resale_post_details(post, broker)
      end)

    posts = ResalePropertyPost.add_contacted_details_for_broker(posts, broker)
    ResalePropertyPost.add_shortlisted_details_for_broker(posts, broker)
  end
end
