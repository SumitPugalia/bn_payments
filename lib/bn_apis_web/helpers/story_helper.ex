defmodule BnApisWeb.Helpers.StoryHelper do
  use BnApisWeb, :view

  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.{Time, ApplicationHelper, HtmlHelper}

  def process_filter_params(params) do
    page = (params["p"] && params["p"] |> String.to_integer()) || 1
    configuration_type_ids = params["configuration_type_ids"]

    configuration_type_ids =
      if is_nil(configuration_type_ids) or configuration_type_ids == "",
        do: [],
        else: configuration_type_ids |> Poison.decode!()

    min_carpet_area =
      if is_binary(params["min_carpet_area"]),
        do: String.to_integer(params["min_carpet_area"]),
        else: params["min_carpet_area"]

    max_carpet_area =
      if is_binary(params["max_carpet_area"]),
        do: String.to_integer(params["max_carpet_area"]),
        else: params["max_carpet_area"]

    city_id = if is_binary(params["city_id"]) and params["city_id"] != "", do: String.to_integer(params["city_id"]), else: nil

    project_type_id =
      if is_binary(params["project_type_id"]) and params["project_type_id"] != "",
        do: String.to_integer(params["project_type_id"]),
        else: nil

    polygon_ids =
      if is_nil(params["polygon_ids"]) or params["polygon_ids"] == "",
        do: [],
        else: params["polygon_ids"] |> Poison.decode!()

    min_price = if is_binary(params["min_price"]), do: String.to_integer(params["min_price"]), else: params["min_price"]
    max_price = if is_binary(params["max_price"]), do: String.to_integer(params["max_price"]), else: params["max_price"]

    possession_by =
      if is_binary(params["possession_by"]) and params["possession_by"] != "",
        do: String.to_integer(params["possession_by"]),
        else: nil

    exclude_story_uuids =
      if params["exclude_story_uuids"] == "" or is_nil(params["exclude_story_uuids"]),
        do: [],
        else: params["exclude_story_uuids"] |> String.split(",")

    processed_params = %{
      "page" => page,
      "configuration_type_ids" => configuration_type_ids,
      "min_carpet_area" => min_carpet_area,
      "max_carpet_area" => max_carpet_area,
      "possession_by" => possession_by,
      "city_id" => city_id,
      "polygon_ids" => polygon_ids,
      "min_price" => min_price,
      "max_price" => max_price,
      "project_type_id" => project_type_id,
      "exclude_story_uuids" => exclude_story_uuids
    }

    Map.merge(params, processed_params)
  end

  def show_team_member_card(organization_id) do
    length(Credential.get_credentials(organization_id)) == 1
  end

  def create_read_matches(read_matches) do
    five_hour = 5 * 60 * 60

    initial_acc = %{
      bucket_matches: [],
      time: 0
    }

    %{bucket_matches: bucket_matches} =
      read_matches
      |> Enum.map(fn %{post_in_context: pic} -> pic end)
      |> Enum.reduce(initial_acc, fn post_match, %{bucket_matches: bucket_matches, time: time} = acc ->
        # bucket by 5 hrs
        time = if time == 0, do: (post_match.call_log_time * 1000) |> Time.minus_time(five_hour), else: time
        acc = %{acc | time: time}

        current = bucket_matches |> Enum.at(-1) || []

        if post_match.call_log_time * 1000 > time do
          current = current ++ [post_match]

          acc
          |> Map.merge(%{
            bucket_matches: (bucket_matches |> Enum.drop(-1)) ++ [current]
          })
        else
          is_diff_large = time - post_match.call_log_time * 1000 > five_hour * 1000

          time =
            if is_diff_large do
              (post_match.call_log_time * 1000) |> Time.minus_time(five_hour)
            else
              time |> Time.minus_time(five_hour)
            end

          acc
          |> Map.merge(%{
            bucket_matches: bucket_matches ++ [[post_match]],
            time: time
          })
        end
      end)

    bucket_matches
    |> Enum.map(fn matches ->
      matches =
        matches
        |> Enum.sort_by(fn post -> post.inserted_at end, &>=/2)

      %{
        type: "READ_MATCHES",
        data: %{
          matches: matches
        }
      }
    end)
  end

  def create_outstanding_matches(outstanding_matches) do
    outstanding_matches
    |> Enum.map(fn %{post_in_context: pic} -> pic end)
    |> Enum.group_by(& &1.assigned_to.uuid)
    |> Enum.sort_by(fn {_key, value} -> {hd(value).inserted_at, hd(value).updation_time} end, &>=/2)
    |> Enum.map(fn {_k, v} -> v end)
    |> Enum.map(fn matches ->
      %{
        type: "OUTSTANDING_MATCHES",
        data: %{
          matches: matches |> Enum.sort_by(fn post -> post.read end, &<=/2)
        }
      }
    end)
  end

  def create_posts_with_matches(posts_with_matches) do
    posts_with_matches
    # |> Enum.map(fn(%{post_in_context: pic}) -> pic end)
    # |> Enum.group_by(&(&1.assigned_to.uuid))
    # |> Enum.sort_by(fn {_key, value} -> {hd(value).inserted_at, hd(value).updation_time} end, &>=/2)
    # |> Enum.map(fn({_k, v}) -> v end)
    |> Enum.map(fn post_with_matches ->
      %{
        type: "POST_MATCHES",
        data: post_with_matches
      }
    end)
  end

  def create_already_contacted_matches(already_contacted_matches) do
    already_contacted_matches
    |> Enum.map(fn %{post_in_context: pic} -> pic end)
    |> Enum.group_by(& &1.assigned_to.uuid)
    |> Enum.sort_by(fn {_key, value} -> hd(value).inserted_at end, &>=/2)
    |> Enum.map(fn {_k, v} -> v end)
    |> Enum.map(fn matches ->
      %{
        type: "ALREADY_CONTACTED_MATCHES",
        data: %{
          matches: matches
        }
      }
    end)
  end

  def create_expiring_posts(posts_expiring) do
    [
      %{
        type: "POSTS_EXPIRING_SOON",
        data: %{
          posts_expiring: posts_expiring
        }
      }
    ]
  end

  def send_story_alert(
        story_uuid,
        user_uuids,
        app_version,
        template_name \\ "broadcast",
        user_id \\ 1,
        notif_type \\ "NEW_STORY_ALERT"
      ) do
    fcm_data = story_uuid |> fetch_story_notif_data(template_name, user_id)
    story_data = (story_uuid |> fetch_story_data(user_id))[:data]

    credentials =
      if user_uuids |> length == 0 do
        Credential.get_active_broker_credentials_above_version(app_version, story_data[:operating_cities], false)
      else
        Credential.get_credentials_from_uuid(user_uuids)
      end

    credentials
    |> Enum.each(fn cred ->
      Exq.enqueue(Exq, "push_notification", BnApis.Notifications.PushNotificationWorker, [
        cred.fcm_id,
        %{data: fcm_data, type: notif_type},
        cred.id,
        cred.notification_platform
      ])
    end)
  end

  def fetch_story_notif_data(story_uuid, template_name, _user_id \\ 1) do
    %{
      url: story_uuid |> broadcast_url(template_name),
      uuid: story_uuid
    }
  end

  def broadcast_url(story_uuid, template_name) do
    ApplicationHelper.hosted_domain_url() <>
      "/api/stories/template" <> "?" <> "story_uuid=#{story_uuid}&template_name=#{template_name}"
  end

  def fetch_story_data(story_uuid, user_id) do
    story = BnApis.Stories.get_story_from_uuid!(story_uuid)
    BnApisWeb.StoryView.render("show.json", story: story, user_id: user_id)
  end

  # 1. generates html specific to broker
  # 2. converts that html to pdf and returns path of that pdf
  def get_broker_card_path(broker_data, with_dummy \\ true) do
    path =
      broker_data
      |> modify_broker_data()
      |> add_broker_card_template_name()
      |> generate_broker_card_html()
      |> HtmlHelper.generate_pdf_from_html(broker_data["page_width"], broker_data["page_height"])

    if with_dummy do
      dummy_pdf_path =
        generate_broker_card_html(%{"template_name" => "dummy.html"})
        |> HtmlHelper.generate_pdf_from_html(broker_data["page_width"], "1", true)

      path |> merge_pdfs(dummy_pdf_path, path)
      File.rm(dummy_pdf_path)
    end

    path
  end

  def modify_broker_data(data) do
    profile_pic =
      if not is_nil(data["profile_pic_url"]),
        do: data["profile_pic_url"],
        else: "https://brokernetwork.app/static/default_profile_pic.png"

    data
    |> Map.merge(%{
      "profile_pic_url" => profile_pic <> "?fit=facearea&facepad=1.75&w=300&h=300"
    })
  end

  # 1. For horizontal pdf fetch horizontal template
  def add_broker_card_template_name(broker_data) do
    template_name =
      if broker_data["page_rotation"] in ["90", "270"] do
        "broker_card_horizontal.html"
      else
        "broker_card.html"
      end

    put_in(broker_data, ["template_name"], template_name)
  end

  def generate_broker_card_html(broker_data) do
    {:safe, html} =
      Phoenix.View.render(BnApisWeb.StoryView, broker_data["template_name"],
        broker_data: broker_data,
        phone_number: broker_data["phone_number"]
      )

    html |> IO.iodata_to_binary()
  end

  # will merge two pdfs and write in the output path
  # if there is directory present in path make sure that directory exists before hand
  def merge_pdfs(pdf_path1, pdf_path2, output_path \\ "#{File.cwd!()}/personalised_sales_kit.pdf") do
    System.cmd("ruby", [
      "#{File.cwd!()}/lib/ruby/pdf_helper.rb",
      "merge_pdf",
      "#{pdf_path1}",
      "#{pdf_path2}",
      "#{output_path}"
    ])
  end

  def add_last_page_dimensions(data, path) do
    [page_width, _page_height, page_rotation] = path |> get_last_page_dimensions()

    # page_height = page_height |> String.to_float()
    # fixed height in mm
    page_height = 500.00
    page_width = page_width |> String.to_float()
    scale = get_scale(page_width, page_height)

    div_top = get_dynamic_top(scale)

    data
    |> Map.merge(%{
      "page_width" => "#{page_width + add_default_width()}",
      "page_height" => "#{page_height + add_default_height()}",
      "page_rotation" => page_rotation,
      "scale" => scale,
      "div_top" => div_top
    })
  end

  ## in pixels
  def get_dynamic_top(scale) do
    100 * scale
  end

  # in mm
  def add_default_height() do
    0
  end

  # in mm
  def add_default_width() do
    0
  end

  def get_scale(page_width, page_height) do
    # 1 mm = 3.7795275591 pixel
    [page_width * 3.7795275591 / 500, page_height * 3.7795275591 / 1100] |> Enum.min()
  end

  def get_last_page_dimensions(path) do
    {dimensions, _} = System.cmd("ruby", ["#{File.cwd!()}/lib/ruby/pdf_helper.rb", "get_last_page_dimensions", "#{path}"])

    dimensions |> String.trim_trailing("\n") |> String.split("\n")
  end
end
