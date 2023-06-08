defmodule BnApis.Commercials do
  alias BnApis.Repo
  alias BnApis.Commercials.CommercialPropertyPoc
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.ReportedCommercialPropertyPost
  alias BnApis.Commercials.CommercialsEnum
  alias BnApis.Documents.Document
  alias BnApis.Commercials.CommercialSiteVisit
  alias BnApis.Helpers.Utils
  alias BnApis.Accounts
  alias BnApis.Commercials.CommercialSendbird
  alias BnApis.Commercials.CommercialBucket
  alias BnApis.Helpers.Time
  alias BnApis.Commercials.CommercialBucketLog
  alias BnApis.Reminder

  @visit_scheduled "SCHEDULED"
  @visit_completed "COMPLETED"
  @visit_cancelled "CANCELLED"
  @visit_deleted "DELETED"

  def admin_list_post(params, employee_id, employee_role_id) do
    params =
      if not is_nil(params["is_commercial_agent"]) do
        if params["is_commercial_agent"], do: params |> Map.merge(%{"assigned_manager_id" => employee_id}), else: params
      else
        params
      end

    CommercialPropertyPost.admin_list_post(params, employee_id, employee_role_id)
  end

  def update_status_for_multiple_posts(post_uuids, comment, status_id, user_id, employee_role_id) do
    CommercialPropertyPost.update_status_for_multiple_posts(post_uuids, comment, status_id, user_id, employee_role_id)
  end

  def fetch_all_shortlisted_posts(params, user_id) do
    broker = Accounts.get_broker_by_user_id(user_id)
    post_uuids = broker.shortlisted_commercial_property_posts |> Enum.map(& &1["post_uuid"])
    response = CommercialPropertyPost.fetch_all_shortlisted_posts(params, user_id, post_uuids)
    {:ok, response}
  end

  def report_post(post_uuid, user_id, reason_id, remarks) do
    post = CommercialPropertyPost.fetch_post_by_uuid(post_uuid)

    if is_nil(post),
      do: {:error, "post not found"},
      else: ReportedCommercialPropertyPost.report_post(post.id, user_id, reason_id, remarks)
  end

  def meta_data() do
    meta_data = CommercialsEnum.get_all_enums()
    {:ok, meta_data}
  end

  def aggregate(params, employee_id, employee_role_id) do
    params =
      if not is_nil(params["is_commercial_agent"]) do
        if params["is_commercial_agent"], do: params |> Map.merge(%{"assigned_manager_id" => employee_id}), else: params
      else
        params
      end

    aggregate_data = CommercialPropertyPost.aggregate(params, employee_id, employee_role_id)
    {:ok, aggregate_data}
  end

  def upload_document(params, user_id) do
    documents = params["documents"]

    if is_list(documents) and length(documents) > 0 do
      case Repo.get_by(CommercialPropertyPost, id: params["post_id"]) do
        nil ->
          {:error, "invalid post id"}

        _post ->
          Document.upload_document(documents, user_id, CommercialsEnum.commercial_property_posts(), "employee")
          {uploaded_docs, _number_of_documents} = Document.get_document(params["post_id"], CommercialsEnum.commercial_property_posts(), true)
          {:ok, %{message: "images uploaded succesfully", uploaded_docs: uploaded_docs, status: true}}
      end
    else
      {:ok, %{message: "No images to be uploaded", uploaded_docs: [], status: false}}
    end
  end

  def remove_document(params) do
    entity_id = if is_binary(params["entity_id"]), do: String.to_integer(params["entity_id"]), else: params["entity_id"]
    doc_id = if is_binary(params["doc_id"]), do: String.to_integer(params["doc_id"]), else: params["doc_id"]
    Document.remove_document(doc_id, entity_id, CommercialsEnum.commercial_property_posts())
  end

  def get_document(post_uuid, is_active) do
    post = CommercialPropertyPost.fetch_post_by_uuid(post_uuid)

    if not is_nil(post) do
      is_active = Utils.parse_boolean_param(is_active)
      {docs, total_count} = Document.get_document(post.id, CommercialsEnum.commercial_property_posts(), is_active)

      response = %{
        "documents" => docs,
        "total_count" => total_count
      }

      {:ok, response}
    else
      {:error, "Post not found"}
    end
  end

  def search_poc(params) do
    CommercialPropertyPoc.search_poc(Map.get(params, "q", ""), Utils.parse_boolean_param(params["is_active"]))
  end

  def create_or_update_poc(phone_number, params) do
    case CommercialPropertyPoc.create_or_update_poc(phone_number, params) do
      {:ok, poc} ->
        response = %{poc_id: poc.id, name: poc.name, phone: poc.phone, email: poc.email, country_code: poc.country_code}
        {:ok, response}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def get_site_visit(params, visit_id) do
    visit_id = if is_binary(visit_id), do: String.to_integer(visit_id), else: visit_id

    case CommercialSiteVisit |> Repo.get_by(id: visit_id) do
      nil -> {:error, "Visit not found"}
      site_visit -> CommercialSiteVisit.get_site_visit(params, site_visit)
    end
  end

  def list_site_visits_for_broker(page, limit, status_id, visit_start_time, visit_end_time, status_ids, broker_id, user_id, app_version \\ nil) do
    visit_status = CommercialsEnum.get_visit_status_identifier_from_id(status_id)
    CommercialSiteVisit.list_site_visits_for_broker(page, limit, visit_status, visit_start_time, visit_end_time, status_ids, broker_id, user_id, app_version)
  end

  def list_site_visits(params, employee_id) do
    params =
      if not is_nil(params["is_commercial_agent"]) do
        if params["is_commercial_agent"], do: params |> Map.merge(%{"assigned_manager_id" => employee_id}), else: params
      else
        params
      end

    CommercialSiteVisit.list_site_visits(params)
  end

  def send_whatsapp_notification_for_site_visit(visit_id, status) do
    Exq.enqueue_in(Exq, "send_whatsapp_message", 3, BnApis.Commercial.CommercialSiteVisitNotification, [visit_id, status])
  end

  def schedule_reminder_for_visit(visit_id, visit_date) do
    reminder_date = visit_date - 60 * 60
    params = %{"entity_id" => visit_id, "reminder_date" => reminder_date, "status" => "REMINDER"}
    entity_type = CommercialSiteVisit.get_schema_name()
    Reminder.create_reminder(params, nil, entity_type)
  end

  def update_visit_reminder_time(visit_id, visit_date) do
    reminder_date = visit_date - 60 * 60
    entity_type = CommercialSiteVisit.get_schema_name()
    reminders = Reminder.get_nearest_reminders(visit_id, entity_type)

    reminders
    |> Enum.each(fn reminder ->
      params = %{"id" => reminder["id"], "reminder_date" => reminder_date}
      Reminder.update_reminder(params, nil)
    end)
  end

  def remove_reminder(visit_id) do
    entity_type = CommercialSiteVisit.get_schema_name()
    reminders = Reminder.get_nearest_reminders(visit_id, entity_type)

    reminders
    |> Enum.each(fn reminder ->
      params = %{"id" => reminder["id"]}
      Reminder.cancel_reminder(params, nil)
    end)
  end

  def create_site_visit(params, broker_id, user_id) do
    visit = CommercialSiteVisit.create_site_visit(params, broker_id)

    case visit do
      {:ok, id} ->
        commercial_post = CommercialPropertyPost |> Repo.get_by(id: params["commercial_property_post_id"])
        {:ok, post} = CommercialPropertyPost.get_post(commercial_post.uuid, user_id, nil, params["app_version"])
        send_whatsapp_notification_for_site_visit(id, @visit_scheduled)
        schedule_reminder_for_visit(id, params["visit_date"])
        {:ok, %{message: "Successfully created", site_visit_id: id, post: post}}

      {:error, msg} ->
        {:error, msg}
    end
  end

  def update_site_visit(visit_id, params, broker_id, user_id, status) do
    visit_id = if is_binary(visit_id), do: String.to_integer(visit_id), else: visit_id
    site_visit = CommercialSiteVisit |> Repo.get_by(id: visit_id)

    cond do
      is_nil(site_visit) ->
        {:error, "Visit not found"}

      site_visit.broker_id != broker_id ->
        {:error, "Broker not authorised to see the visit"}

      true ->
        commercial_post = CommercialPropertyPost |> Repo.get_by(id: site_visit.commercial_property_post_id)

        case status do
          @visit_scheduled ->
            visit_date = if not is_nil(params["visit_date"]), do: Utils.parse_to_integer(params["visit_date"]), else: site_visit.visit_date
            change = params |> Map.take(["visit_remarks"]) |> Map.put("visit_date", visit_date)
            CommercialSiteVisit.update_site_visit(site_visit, change)
            {:ok, post} = CommercialPropertyPost.get_post(commercial_post.uuid, user_id, nil, params["app_version"])

            if not is_nil(visit_date) and visit_date != site_visit.visit_date do
              send_whatsapp_notification_for_site_visit(visit_id, @visit_scheduled)
              update_visit_reminder_time(visit_id, visit_date)
            end

            {:ok, %{message: "Successfully Updated", site_visit_id: visit_id, post: post}}

          @visit_deleted ->
            if(site_visit.visit_status == @visit_scheduled) do
              change = %{"visit_status" => @visit_deleted, "reason_id" => params["reason_id"]}
              CommercialSiteVisit.update_site_visit(site_visit, change)
              {:ok, post} = CommercialPropertyPost.get_post(commercial_post.uuid, user_id, nil, params["app_version"])
              send_whatsapp_notification_for_site_visit(visit_id, @visit_deleted)
              remove_reminder(visit_id)
              {:ok, %{message: "Successfully Deleted", site_visit_id: visit_id, post: post}}
            else
              {:error, "Invalid status, can't change status"}
            end
        end
    end
  end

  def update_site_visit_for_admin(visit_id, user_id, status) do
    site_visit = CommercialSiteVisit |> Repo.get_by(id: visit_id)

    cond do
      is_nil(site_visit) ->
        {:error, "Either Visit not found"}

      true ->
        case status do
          @visit_completed ->
            if(site_visit.visit_status == @visit_scheduled) do
              change = %{"visit_status" => @visit_completed, "completed_by_id" => user_id}
              CommercialSiteVisit.update_site_visit(site_visit, change)
              {:ok, "Successfully Completed"}
            else
              {:ok, "Invalid status ,can't change booking"}
            end

          @visit_cancelled ->
            if(site_visit.visit_status == @visit_scheduled) do
              change = %{"visit_status" => @visit_cancelled, "cancelled_by_id" => user_id}
              CommercialSiteVisit.update_site_visit(site_visit, change)
              {:ok, "Successfully Cancelled"}
            else
              {:ok, "Invalid status, can't change booking"}
            end
        end
    end
  end

  def create_channel(post_uuid, broker_id) do
    commercial_post = CommercialPropertyPost.fetch_post_by_uuid(post_uuid)
    CommercialSendbird.create_commercial_channel(commercial_post.id, broker_id)
  end

  def get_reported_post(post_uuid) do
    post = CommercialPropertyPost.fetch_post_by_uuid(post_uuid)

    case post do
      nil ->
        {:ok, %{message: "post not exist"}}

      post ->
        reports = ReportedCommercialPropertyPost.get_reported_post(post.id)
        {:ok, %{reports: reports}}
    end
  end

  def create_bucket(bucket_name, broker_id) do
    CommercialBucket.create(bucket_name, broker_id)
  end

  def list_bucket(params, broker_id) do
    CommercialBucket.list_bucket(params, broker_id)
  end

  def list_bucket_status_post(id, status_id, p, page_size, broker_id, user_id) do
    CommercialBucket.list_bucket_status_post(id, status_id, p, page_size, broker_id, user_id)
  end

  def get_bucket(bucket_id, broker_id) do
    bucket_id = Utils.parse_to_integer(bucket_id)
    CommercialBucket.get_bucket(bucket_id, broker_id)
  end

  def add_or_remove_post_in_bucket(post_uuid, status_id, bucket_id, is_to_be_added, broker_id) do
    bucket = CommercialBucket |> Repo.get_by(broker_id: broker_id, id: bucket_id, active: true)
    post = CommercialPropertyPost |> Repo.get_by(uuid: post_uuid, status: CommercialPropertyPost.get_active_status())

    cond do
      is_nil(post) ->
        {:error, "post not found"}

      is_nil(bucket) ->
        {:error, "bucket not found"}

      true ->
        {status, content} = add_or_remove_post(bucket, status_id, post_uuid, is_to_be_added)

        if status == :ok do
          CommercialBucket.update(bucket, content)
          msg = if is_to_be_added, do: "You have successfully added post to the Bucket!", else: "You have successfully removed post to the Bucket!"

          case CommercialBucket.get_bucket(bucket_id, broker_id) do
            {:error, msg} ->
              {:error, msg}

            {:ok, data} ->
              {:ok, %{message: msg, bucket_details: data}}
          end
        else
          {:error, content}
        end
    end
  end

  def add_or_remove_post(bucket, status_id, post_uuid, is_to_be_added) do
    current_time = Timex.now() |> Time.naive_to_epoch_in_sec()
    status = CommercialsEnum.get_bucket_status_identifier_from_id(status_id)
    [options, visits, shortlisted, finalized, negotiation] = get_bucket_status_enums()

    {status, content} =
      if is_to_be_added do
        case status do
          ^options ->
            post_uuids = bucket.option_posts |> Enum.map(& &1["post_uuid"])

            if Enum.member?(post_uuids, post_uuid) do
              {:error, "post is already present in bucket"}
            else
              {:ok, %{"option_posts" => bucket.option_posts ++ [%{"post_uuid" => post_uuid, "added_on" => current_time}]}}
            end

          ^visits ->
            post_uuids = bucket.visit_posts |> Enum.map(& &1["post_uuid"])

            if Enum.member?(post_uuids, post_uuid) do
              {:error, "post is already present in bucket"}
            else
              {:ok, %{"visit_posts" => bucket.visit_posts ++ [%{"post_uuid" => post_uuid, "added_on" => current_time}]}}
            end

          ^shortlisted ->
            post_uuids = bucket.shortlisted_posts |> Enum.map(& &1["post_uuid"])

            if Enum.member?(post_uuids, post_uuid) do
              {:error, "post is already present in bucket"}
            else
              {:ok, %{"shortlisted_posts" => bucket.shortlisted_posts ++ [%{"post_uuid" => post_uuid, "added_on" => current_time}]}}
            end

          ^finalized ->
            post_uuids = bucket.finalized_posts |> Enum.map(& &1["post_uuid"])

            if Enum.member?(post_uuids, post_uuid) do
              {:error, "post is already present in bucket"}
            else
              {:ok, %{"finalized_posts" => bucket.finalized_posts ++ [%{"post_uuid" => post_uuid, "added_on" => current_time}]}}
            end

          ^negotiation ->
            post_uuids = bucket.negotiation_posts |> Enum.map(& &1["post_uuid"])

            if Enum.member?(post_uuids, post_uuid) do
              {:error, "post is already present in bucket"}
            else
              {:ok, %{"negotiation_posts" => bucket.negotiation_posts ++ [%{"post_uuid" => post_uuid, "added_on" => current_time}]}}
            end

          _ ->
            {:error, "invalid status"}
        end
      else
        case status do
          ^options ->
            post_uuids = bucket.option_posts |> Enum.map(& &1["post_uuid"])

            if not Enum.member?(post_uuids, post_uuid) do
              {:error, "post is not present in bucket"}
            else
              {:ok, %{"option_posts" => List.delete(bucket.option_posts, bucket.option_posts |> Enum.find(&(&1["post_uuid"] == post_uuid)))}}
            end

          ^visits ->
            post_uuids = bucket.visit_posts |> Enum.map(& &1["post_uuid"])

            if not Enum.member?(post_uuids, post_uuid) do
              {:error, "post is not present in bucket"}
            else
              {:ok, %{"visit_posts" => List.delete(bucket.visit_posts, bucket.visit_posts |> Enum.find(&(&1["post_uuid"] == post_uuid)))}}
            end

          ^shortlisted ->
            post_uuids = bucket.shortlisted_posts |> Enum.map(& &1["post_uuid"])

            if not Enum.member?(post_uuids, post_uuid) do
              {:error, "post is not present in bucket"}
            else
              {:ok, %{"shortlisted_posts" => List.delete(bucket.shortlisted_posts, bucket.shortlisted_posts |> Enum.find(&(&1["post_uuid"] == post_uuid)))}}
            end

          ^finalized ->
            post_uuids = bucket.finalized_posts |> Enum.map(& &1["post_uuid"])

            if not Enum.member?(post_uuids, post_uuid) do
              {:error, "post is not present in bucket"}
            else
              {:ok, %{"finalized_posts" => List.delete(bucket.finalized_posts, bucket.finalized_posts |> Enum.find(&(&1["post_uuid"] == post_uuid)))}}
            end

          ^negotiation ->
            post_uuids = bucket.negotiation_posts |> Enum.map(& &1["post_uuid"])

            if not Enum.member?(post_uuids, post_uuid) do
              {:error, "post is not present in bucket"}
            else
              {:ok, %{"negotiation_posts" => List.delete(bucket.negotiation_posts, bucket.negotiation_posts |> Enum.find(&(&1["post_uuid"] == post_uuid)))}}
            end

          _ ->
            {:error, "invalid status"}
        end
      end

    {status, content}
  end

  def remove_bucket(bucket_id, broker_id) do
    bucket = CommercialBucket |> Repo.get_by(broker_id: broker_id, id: bucket_id, active: true)

    case bucket do
      nil ->
        {:error, "bucket not found"}

      bucket ->
        res = CommercialBucket.update(bucket, %{"active" => false})

        case res do
          {:ok, _msg} -> {:ok, "removed successfully"}
          {:error, ch} -> {:error, ch}
        end
    end
  end

  def mark_bucket_viewed(uuid) do
    bucket = CommercialBucket |> Repo.get_by(uuid: uuid, active: true)

    case bucket do
      nil ->
        {:error, "bucket not found"}

      bucket ->
        CommercialBucketLog.create(bucket.id, bucket.broker_id)
        CommercialBucket.send_bucket_view_notif(bucket)
    end
  end

  def remove_bucket_status(status_id, bucket_id, broker_id) do
    bucket = CommercialBucket |> Repo.get_by(broker_id: broker_id, id: bucket_id, active: true)
    status = Utils.parse_to_integer(status_id) |> CommercialsEnum.get_bucket_status_identifier_from_id()
    [options, visits, shortlisted, finalized, negotiation] = get_bucket_status_enums()

    case bucket do
      nil ->
        {:error, "bucket not found"}

      bucket ->
        res =
          case status do
            ^options ->
              CommercialBucket.update(bucket, %{"option_posts" => []})

            ^visits ->
              CommercialBucket.update(bucket, %{"visit_posts" => []})

            ^shortlisted ->
              CommercialBucket.update(bucket, %{"shortlisted_posts" => []})

            ^finalized ->
              CommercialBucket.update(bucket, %{"finalized_posts" => []})

            ^negotiation ->
              CommercialBucket.update(bucket, %{"negotiation_posts" => []})

            _ ->
              {:error, "invalid status"}
          end

        {:ok, data} = CommercialBucket.get_bucket(bucket_id, broker_id)

        case res do
          {:ok, _msg} -> {:ok, %{message: "removed Successfully", bucket_details: data}}
          {:error, ch} -> {:error, ch}
        end
    end
  end

  def get_bucket_details(bucket_uuid, token_id) do
    bucket = CommercialBucket |> Repo.get_by(uuid: bucket_uuid, token_id: token_id, active: true)

    case bucket do
      nil ->
        {:error, "bucket not found"}

      bucket ->
        CommercialBucket.get_bucket(bucket.id, bucket.broker_id, true)
    end
  end

  defp get_bucket_status_enums() do
    options = CommercialBucket.get_bucket_options()
    visits = CommercialBucket.get_bucket_visits()
    shortlisted = CommercialBucket.get_bucket_shortlisted()
    finalized = CommercialBucket.get_bucket_finalized()
    negotiation = CommercialBucket.get_bucket_negotiation()
    [options, visits, shortlisted, finalized, negotiation]
  end
end
