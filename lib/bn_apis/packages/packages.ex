defmodule BnApis.Packages do
  alias BnApis.{Packages, Posts, Repo}
  alias BnApis.Packages.{UserOrder, UserPackage, Payment, Invoice}
  alias BnApis.Memberships.{Membership, MembershipOrder}
  alias BnApis.Orders.{Order, OrderPayment, MatchPlusPackage}
  alias BnApis.Helpers.{ApplicationHelper, Time, Utils}

  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  alias BnApis.Accounts.OwnersBrokerEmployeeMapping
  alias BnApis.Helpers.Time
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Places.Polygon

  import Ecto.Query
  require Logger

  @allowed_assigned_employee_editable_in_sec 48 * 60 * 60
  @captured_status Payment.captured_status()
  @failed_status Payment.failed_status()

  ##############################################################################
  #  USER ORDER
  ##############################################################################

  ## will send opts: [auto_renew: false] if want to override auto_renew value incase of one time payment
  def create_user_order(user, packages, opts \\ []) do
    %{"profile" => %{"broker_id" => broker_id}} = user
    user_packages = create_user_package(broker_id, packages, opts)
    amount = calculate_total_amount(packages)

    %UserOrder{}
    |> UserOrder.changeset(%{
      amount: amount,
      amount_paid: 0,
      amount_due: amount,
      created_at: Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> DateTime.to_unix(),
      currency: :inr,
      status: :created,
      broker_id: broker_id,
      user_packages: user_packages
    })
    |> Repo.insert()
  end

  def update_user_order(user_order, params) do
    user_order
    |> UserOrder.update_changeset(params)
    |> Repo.update()
  end

  ## Returns only one result
  def get_user_order_by(params, preload \\ []) do
    params = params |> Keyword.new()

    UserOrder
    |> preload(^preload)
    |> limit(1)
    |> Repo.get_by(params)
  end

  ## Returns all results
  def get_all_user_order_by(%{status: status, last_created_at: last_created_at}) do
    UserOrder
    |> where([o], o.status == ^status)
    |> where([o], o.created_at < ^last_created_at)
    |> Repo.all()
  end

  def fetch_user_orders_txn_history(params, broker_id) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "5") |> String.to_integer()
    {current_time, beginning_of_month, end_of_month_minus_one_day, end_of_month_five_pm, end_of_month} = Time.get_current_month_limits_in_unix()
    current_time_less_than_end_of_month_minus_one_day = current_time < end_of_month_minus_one_day
    current_time_less_than_end_of_month_five_pm = current_time < end_of_month_five_pm

    query =
      UserOrder
      |> where([o], o.status != ^UserOrder.created_status())
      |> where([o], o.broker_id == ^broker_id)
      |> join(:inner, [o], op in Payment, on: o.id == op.user_order_id)
      |> join(:left, [o, op], i in Invoice, on: op.id == i.payment_id)
      |> join(:inner, [o, op, i], up in UserPackage, on: o.id == up.user_order_id)
      |> order_by([o, op, i, up], desc: op.created_at)
      |> distinct([o, op, i, up], op.payment_id)
      |> select([o, op, i, up], %{
        pg_order_id: o.pg_order_id,
        order_id: o.id,
        pg_payment_id: op.payment_id,
        order_status:
          fragment(
            """
              CASE WHEN ? = 'captured' THEN 'SUCCESS' ELSE 'PENDING' END
            """,
            op.payment_status
          ),
        order_invoice_url: i.invoice_url,
        is_gst_invoice: i.is_gst_invoice,
        capture_gst:
          fragment(
            """
              CASE
                WHEN ? is FALSE AND ? > ? and ? < ? and ? THEN TRUE
                WHEN ? is FALSE AND ? > ? and ? < ? and ? THEN TRUE
                ELSE FALSE
              END
            """,
            i.is_gst_invoice,
            op.created_at,
            ^beginning_of_month,
            op.created_at,
            ^end_of_month_minus_one_day,
            ^current_time_less_than_end_of_month_minus_one_day,
            i.is_gst_invoice,
            op.created_at,
            ^end_of_month_minus_one_day,
            op.created_at,
            ^end_of_month,
            ^current_time_less_than_end_of_month_five_pm
          ),
        order_status_title:
          fragment(
            """
              CASE WHEN ? = 'captured' THEN 'Successful' WHEN ? = 'failed' THEN 'Failed' ELSE 'In Progress' END
            """,
            op.payment_status,
            op.payment_status
          ),
        order_creation_date: op.created_at,
        order_amount:
          fragment(
            """
              CAST((?) as VARCHAR)
            """,
            op.amount
          ),
        response_message: nil,
        resp_code: nil,
        payment_mode: "billdesk",
        auto_renew: up.auto_renew
      })

    total_count = query |> Repo.aggregate(:count, :id)

    response = query |> limit(^size) |> offset(^((page_no - 1) * size)) |> Repo.all()

    has_more = Enum.count(response) >= size
    {response, has_more, total_count}
  end

  ##############################################################################
  #  Payments
  ##############################################################################

  def create_or_update_payment(payment, params) do
    payment
    |> Payment.changeset(params)
    |> Repo.insert_or_update()
  end

  def update_payment_from_txn(txn, payment \\ nil, send_notification \\ false) do
    payment = if is_nil(payment), do: %Payment{}, else: payment

    with {:user_order_check, user_order} when not is_nil(user_order) <-
           {:user_order_check, Packages.get_user_order_by(%{id: txn.orderid}, [:user_packages, :payments])},
         order_status <- get_order_status(txn.auth_status, txn.transaction_error_code, txn.transaction_error_type),
         updated_order_params <- %{
           amount_paid: if(order_status == UserOrder.paid_status(), do: get_amount(txn.amount), else: 0),
           amount_due: if(order_status == UserOrder.paid_status(), do: user_order.amount - get_amount(txn.amount), else: user_order.amount_due),
           status: order_status,
           is_captured: is_captured?(txn.auth_status, txn.transaction_error_code, txn.transaction_error_type),
           user_packages:
             updated_user_packages(user_order.user_packages, %{
               status: get_user_package_status(txn.auth_status, txn.transaction_error_code, txn.transaction_error_type),
               mandate_mode: txn.mandate_mode,
               subscription_id: txn.subscription_id,
               mandate_id: txn.mandate_id
             })
         },
         {:ok, user_order} <- Packages.update_user_order(user_order, updated_order_params),
         payment_params <-
           %{
             payment_data: txn.raw_response,
             created_at: Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> DateTime.to_unix(),
             currency: "inr",
             payment_id: txn.transactionid,
             payment_status: get_payment_status(txn.auth_status, txn.transaction_error_code, txn.transaction_error_type),
             amount: get_amount(txn.amount),
             payment_gateway: :billdesk,
             international: false,
             amount_refunded: 0,
             refund_status: nil,
             captured: is_captured?(txn.auth_status, txn.transaction_error_code, txn.transaction_error_type),
             description: "",
             payment_method_type: txn.payment_method_type,
             tax: nil,
             fee: nil,
             email: nil,
             contact: nil,
             note: nil,
             user_order_id: user_order.id
           }
           |> Enum.reject(fn {_k, v} -> is_nil(v) end)
           |> Enum.into(%{}),
         {:ok, _payment} <- Packages.create_or_update_payment(payment, payment_params),
         payment_status <- get_payment_status(txn.auth_status, txn.transaction_error_code, txn.transaction_error_type),
         _response <- maybe_create_invoice(payment_status, user_order),
         _response <- maybe_send_notification(payment_status, user_order, send_notification) do
      :ok
    else
      error -> error
    end
  end

  ##############################################################################
  #  USER PACKAGE
  ##############################################################################

  ## Figure out what how we manage for mandate_id, invoice_id, subscription_id etc When we start recurring Payment Flow.
  def create_user_package(broker_id, packages, opts) when is_list(packages) do
    packages
    |> Enum.reduce([], fn package, created_package -> [create_user_package(broker_id, package, opts) | created_package] end)
  end

  ## Based on Package Type commercial / owners we need to extend package
  def create_user_package(broker_id, package, opts) do
    latest_user_package =
      fetch_user_package_by(%{"package_id" => package.id, "broker_id" => broker_id, "statuses" => [:active, :cancelled], "active" => true}, desc: :current_end) |> List.first()

    {current_start, current_end} = get_current_start_and_end(package, latest_user_package)

    %{
      status: :pending,
      broker_id: broker_id,
      current_start: current_start,
      current_end: current_end,
      match_plus_package_id: package.id,
      type: package.package_type,
      auto_renew: Keyword.get(opts, :auto_renew, false)
    }
  end

  ## Returns only one result
  def get_user_package_by(params, preload \\ []) do
    params = params |> Keyword.new()

    UserPackage
    |> preload(^preload)
    |> limit(1)
    |> Repo.get_by(params)
  end

  def update_user_package(user_package, params) do
    user_package
    |> UserPackage.update_changeset(params)
    |> Repo.update()
  end

  def fetch_user_package_by(params, order_by \\ [], preload \\ []) do
    query = UserPackage

    query =
      if not is_nil(params["package_id"]) do
        query |> where([u], u.match_plus_package_id == ^params["package_id"])
      else
        query
      end

    query =
      if not is_nil(params["broker_id"]) do
        query |> where([u], u.broker_id == ^params["broker_id"])
      else
        query
      end

    query =
      if not is_nil(params["status"]) do
        query |> where([u], u.status == ^params["status"])
      else
        query
      end

    query =
      if not is_nil(params["statuses"]) do
        query |> where([u], u.status in ^params["statuses"])
      else
        query
      end

    query =
      if not is_nil(params["active"]) do
        if params["active"] do
          query |> where([u], u.current_end > ^Time.now_to_epoch_sec())
        else
          query |> where([u], u.current_end < ^Time.now_to_epoch_sec())
        end
      else
        query
      end

    query |> preload(^preload) |> order_by(^order_by) |> Repo.all()
  end

  ##############################################################################
  #  USER PACKAGE
  ##############################################################################

  ## Currently, we fetch it from memberships, orders & user_order.
  ## Moving forward we will migrate all to user_order.
  def get_transaction_history(broker_id, params) do
    {mo_data, mo_has_more, mo_total_count} = fetch_membership_orders_txn_history(params, broker_id)
    {o_data, o_has_more, o_total_count} = fetch_orders_txn_history(params, broker_id)
    {up_data, up_has_more, up_total_count} = fetch_user_orders_txn_history(params, broker_id)

    data =
      (mo_data ++ o_data ++ up_data)
      |> Enum.sort_by(fn txn -> txn[:order_creation_date] end, &>=/2)

    total_count = mo_total_count + o_total_count + up_total_count
    has_more = mo_has_more || o_has_more || up_has_more

    data = %{
      "data" => data,
      "has_more" => has_more,
      "total_count" => total_count
    }

    {:ok, data}
  end

  defp fetch_membership_orders_txn_history(params, broker_id) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "5") |> String.to_integer()
    {current_time, beginning_of_month, end_of_month_minus_one_day, end_of_month_five_pm, end_of_month} = Time.get_current_month_limits_in_unix()
    current_time_less_than_end_of_month_minus_one_day = current_time < end_of_month_minus_one_day
    current_time_less_than_end_of_month_five_pm = current_time < end_of_month_five_pm

    query =
      MembershipOrder
      |> join(:inner, [mo], m in Membership, on: mo.membership_id == m.id)
      |> join(:left, [mo, m], mpp in MatchPlusPackage, on: m.match_plus_package_id == mpp.id)
      |> where([mo, m], m.broker_id == ^broker_id)
      |> where([mo, m], mo.order_status == "SUCCESS" or not is_nil(mo.resp_code))
      |> order_by([mo, m], desc: mo.order_creation_date)
      |> select([mo, m, mpp], %{
        pg_order_id: mo.order_id,
        order_id:
          fragment(
            """
              CAST((?) as VARCHAR)
            """,
            mo.id
          ),
        pg_payment_id: mo.txn_id,
        order_status: mo.order_status,
        order_invoice_url: mo.invoice_url,
        is_gst_invoice: mo.is_gst_invoice,
        capture_gst:
          fragment(
            """
              CASE
                WHEN ? is FALSE AND ? > ? and ? < ? and ? THEN TRUE
                WHEN ? is FALSE AND ? > ? and ? < ? and ? THEN TRUE
                ELSE FALSE
              END
            """,
            mo.is_gst_invoice,
            mo.order_creation_date,
            ^beginning_of_month,
            mo.order_creation_date,
            ^end_of_month_minus_one_day,
            ^current_time_less_than_end_of_month_minus_one_day,
            mo.is_gst_invoice,
            mo.order_creation_date,
            ^end_of_month_minus_one_day,
            mo.order_creation_date,
            ^end_of_month,
            ^current_time_less_than_end_of_month_five_pm
          ),
        order_status_title:
          fragment(
            """
              CASE WHEN ? = 'SUCCESS' THEN 'Successful' WHEN ? = 'FAIL' THEN 'Failed' ELSE 'In Progress' END
            """,
            mo.order_status,
            mo.order_status
          ),
        order_creation_date: mo.order_creation_date,
        order_amount: mo.order_amount,
        response_message: mo.response_message,
        resp_code: mo.resp_code,
        payment_mode: "paytm",
        auto_renew: true
      })

    total_count = query |> Repo.aggregate(:count, :id)

    response = query |> limit(^size) |> offset(^((page_no - 1) * size)) |> Repo.all()

    has_more = Enum.count(response) >= size
    {response, has_more, total_count}
  end

  defp fetch_orders_txn_history(params, broker_id) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "5") |> String.to_integer()
    {current_time, beginning_of_month, end_of_month_minus_one_day, end_of_month_five_pm, end_of_month} = Time.get_current_month_limits_in_unix()
    current_time_less_than_end_of_month_minus_one_day = current_time < end_of_month_minus_one_day
    current_time_less_than_end_of_month_five_pm = current_time < end_of_month_five_pm

    query =
      Order
      |> join(:inner, [o], op in OrderPayment, on: o.id == op.order_id)
      |> where([o, op], o.broker_id == ^broker_id)
      |> where([o, op], o.status == ^Order.paid_status())
      |> where([o, op], op.razorpay_payment_status == ^OrderPayment.captured_status())
      |> order_by([o, op], desc: op.created_at)
      |> select([o, op], %{
        pg_order_id: o.razorpay_order_id,
        order_id:
          fragment(
            """
              CAST((?) as VARCHAR)
            """,
            o.id
          ),
        pg_payment_id: op.razorpay_payment_id,
        order_status:
          fragment(
            """
              CASE WHEN ? = 'paid' THEN 'SUCCESS' ELSE 'PENDING' END
            """,
            o.status
          ),
        order_invoice_url: o.invoice_url,
        is_gst_invoice: o.is_gst_invoice,
        capture_gst:
          fragment(
            """
              CASE
                WHEN ? is FALSE AND ? > ? and ? < ? and ? THEN TRUE
                WHEN ? is FALSE AND ? > ? and ? < ? and ? THEN TRUE
                ELSE FALSE
              END
            """,
            o.is_gst_invoice,
            op.created_at,
            ^beginning_of_month,
            op.created_at,
            ^end_of_month_minus_one_day,
            ^current_time_less_than_end_of_month_minus_one_day,
            o.is_gst_invoice,
            op.created_at,
            ^end_of_month_minus_one_day,
            op.created_at,
            ^end_of_month,
            ^current_time_less_than_end_of_month_five_pm
          ),
        order_status_title: "Successful",
        order_creation_date: op.created_at,
        order_amount:
          fragment(
            """
              CAST((? / 100) as VARCHAR)
            """,
            op.amount
          ),
        response_message: nil,
        resp_code: nil,
        payment_mode: "razorpay",
        auto_renew: false
      })

    total_count = query |> Repo.aggregate(:count, :id)

    response = query |> limit(^size) |> offset(^((page_no - 1) * size)) |> Repo.all()

    has_more = Enum.count(response) >= size
    {response, has_more, total_count}
  end

  ##############################################################################
  #  Packages Invoice
  ##############################################################################

  def create_invoice(user_order, notify_broker \\ false) do
    Exq.enqueue(Exq, "invoices", BnApis.Orders.UserOrderInvoiceWorker, [user_order.id, notify_broker])
  end

  def update_invoice_details(invoice, user_order_id, params) do
    updated_invoice_res = invoice |> Invoice.update_changeset(params) |> Repo.update()

    case updated_invoice_res do
      {:ok, _updated_invoice} ->
        Exq.enqueue(Exq, "invoices", BnApis.Orders.UserOrderInvoiceWorker, [user_order_id, true])

      {:error, _error} ->
        :ok
    end

    updated_invoice_res
  end

  ##############################################################################
  #  GET DATA
  ##############################################################################

  def get_data(nil) do
    %{
      "mode" => "user_package",
      "is_match_plus_active" => false,
      "banner_text" => Posts.get_total_owner_posts() <> "+ owner properties are live",
      "banner_button_text" => "Subscribe",
      "display_renewal_banner" => true,
      # BLUE
      "banner_color" => "#cfe2f3"
    }
  end

  def get_data(user_package) do
    city_id = user_package.broker.operating_city
    latest_paid_order = user_package.user_order
    is_match_plus_active = user_package.current_end > Time.now_to_epoch_sec()

    {banner_text, banner_button_text, banner_color} = {
      Posts.get_total_owner_posts(city_id) <> "+ owner properties are live",
      "Subscribe",
      # BLUE
      "#cfe2f3"
    }

    billing_end_at_in_days = Utils.date_in_days(user_package.current_end)

    data = %{
      "mode" => "user_package",
      "is_match_plus_active" => is_match_plus_active,
      "billing_start_at" => user_package.current_start,
      "billing_end_at" => user_package.current_end,
      "billing_end_at_in_days" => billing_end_at_in_days,
      "display_renewal_banner" => true,
      "banner_text" => banner_text,
      "banner_button_text" => banner_button_text,
      "banner_color" => banner_color,
      "next_billing_start_at" => nil,
      "next_billing_end_at" => nil,
      "order_id" => user_package.id,
      "pg_order_id" => latest_paid_order.pg_order_id,
      "payment_gateway" => "billdesk",
      "order_is_client_side_payment_successful" => false,
      "order_status" => latest_paid_order.status |> to_string(),
      "order_created_at" => latest_paid_order.inserted_at,
      "latest_paid_order_for_number_of_months" => nil,
      "has_latest_paid_order" => not is_nil(latest_paid_order)
    }

    # override
    {next_billing_start_at, next_billing_end_at} = get_next_billing_start_and_end(user_package.match_plus_package, user_package)
    is_client_side_payment_successful = latest_paid_order.is_client_side_payment_successful
    display_renewal_banner = not if is_nil(user_package.auto_renew), do: false, else: user_package.auto_renew

    {banner_text, banner_button_text, banner_color} =
      cond do
        is_match_plus_active == true and billing_end_at_in_days == 1 ->
          {
            "Your Subscription is ending today",
            "Renew",
            # GREEN
            "#F4CCCC"
          }

        is_match_plus_active == true and billing_end_at_in_days <= 5 ->
          {
            "Your Subscription is ending in #{billing_end_at_in_days} days",
            "Renew",
            # GREEN
            "#F4CCCC"
          }

        is_match_plus_active == true ->
          {
            "Your Subscription will be active for #{billing_end_at_in_days} days",
            "Extend",
            # GREEN
            "#78EDA9"
          }

        is_match_plus_active == false and Time.get_difference_in_days_with_epoch(user_package.current_end) > 30 and
            Enum.member?([1, 37], city_id) ->
          {
            "🚫 Your Subsciption was expired. 🚫\n🎉 Check out new offers just for you! 🎉",
            "Renew",
            # RED
            "#F4CCCC"
          }

        is_match_plus_active == false ->
          {
            "Your Subscription has ended",
            "Renew",
            # RED
            "#F4CCCC"
          }

        true ->
          {
            Posts.get_total_owner_posts(city_id) <> "+ owner properties are live",
            "Subscribe",
            # BLUE
            "#cfe2f3"
          }
      end

    latest_paid_order_for_number_of_months = floor(user_package.match_plus_package.validity_in_days / MatchPlusPackage.days_in_month())

    latest_paid_order_package = user_package.match_plus_package |> get_match_plus_package_data()

    allow_extension =
      if is_nil(billing_end_at_in_days) or billing_end_at_in_days <= 30,
        do: not if(is_nil(user_package.auto_renew), do: true, else: user_package.auto_renew),
        else: false

    data =
      data
      |> Map.merge(%{
        "latest_paid_order_package" => latest_paid_order_package,
        "latest_paid_order_for_number_of_months" => latest_paid_order_for_number_of_months,
        "billing_start_at" => user_package.current_start,
        "billing_end_at" => user_package.current_end,
        "billing_end_at_in_days" => billing_end_at_in_days,
        "allow_extension" => allow_extension,
        "display_renewal_banner" => display_renewal_banner,
        "banner_text" => banner_text,
        "banner_button_text" => banner_button_text,
        "banner_color" => banner_color,
        "next_billing_start_at" => next_billing_start_at,
        "next_billing_end_at" => next_billing_end_at,
        "order_id" => latest_paid_order.id,
        "pg_order_id" => latest_paid_order.pg_order_id,
        "order_is_client_side_payment_successful" => is_client_side_payment_successful,
        "order_status" => latest_paid_order.status,
        "order_created_at" => latest_paid_order.inserted_at,
        "subscription_status" => get_subscription_status(next_billing_start_at)
      })

    city_offer = if city_id in ApplicationHelper.diwali_offer_applied_cities(), do: true, else: false

    if city_offer == true do
      {display_offer_banner, allow_extension} =
        if is_match_plus_active do
          # GMT Wednesday, 19 October 2022 00:00:00
          order_creation_time = latest_paid_order.inserted_at |> Time.naive_to_epoch_in_sec()

          if order_creation_time >= ApplicationHelper.offer_start_time_epoch() do
            {false, false}
          else
            {true, true}
          end
        else
          {true, true}
        end

      data
      |> Map.merge(%{
        "display_offer_banner" => display_offer_banner,
        "allow_extension" => allow_extension
      })
    else
      data
    end
  end

  def get_data_by_broker(broker) do
    %{"broker_id" => broker.id, "statuses" => [:active, :cancelled]}
    |> Packages.fetch_user_package_by([desc: :current_end], [:user_order, :broker, :match_plus_package, user_order: :payments])
    |> List.first()
    |> Packages.get_data()
  end

  def get_match_plus_package_data(nil) do
    %{}
  end

  def get_match_plus_package_data(package) do
    validity_in_days = package.validity_in_days

    offer_days =
      cond do
        package.offer_title == "Extra 30 days" -> 30
        package.offer_title == "Extra 45 days" -> 45
        package.offer_title == "Extra 60 days" -> 60
        true -> 0
      end

    number_of_months = floor((validity_in_days - offer_days) / MatchPlusPackage.days_in_month())
    price_per_month = floor(package.amount_in_rupees / number_of_months)

    %{
      id: package.id,
      active: package.status_id == MatchPlusPackage.active_status_id(),
      uuid: package.uuid,
      original_price: package.original_amount_in_rupees,
      price: package.amount_in_rupees,
      validity_in_days: validity_in_days,
      number_of_months: number_of_months,
      price_per_month: price_per_month,
      offer_applied: package.original_amount_in_rupees != package.amount_in_rupees,
      offer_title: package.offer_title,
      offer_text: package.offer_text,
      default_selection: package.is_default,
      autopay: package.autopay,
      city_id: package.city_id,
      payment_gateway: package.payment_gateway
    }
  end

  def filter_owner_panel_query(params) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "10") |> String.to_integer()

    query =
      UserPackage
      |> join(:inner, [up], ord in UserOrder, on: up.user_order_id == ord.id)
      |> where([up, ord], ord.status == ^UserOrder.paid_status())
      |> join(:inner, [up, ord], op in Payment, on: op.user_order_id == ord.id)
      |> where([mp, ord, op], op.payment_status == ^Payment.captured_status())
      |> join(:inner, [up, ord, op], cred in Credential, on: up.broker_id == cred.broker_id and cred.active == true)
      |> join(:inner, [up, ord, op, cred], bro in Broker, on: up.broker_id == bro.id)
      |> join(:left, [ups, s, op, cred, bro], obem in OwnersBrokerEmployeeMapping, on: obem.broker_id == ups.broker_id and obem.active == true)
      |> join(:left, [ups, s, op, cred, bro, obem], emp in EmployeeCredential, on: obem.employees_credentials_id == emp.id)
      |> join(:left, [ups, s, op, cred, bro, obem, emp], pl in Polygon, on: bro.polygon_id == pl.id)

    query =
      if not is_nil(params["is_match_plus_active"]) do
        status = if params["is_match_plus_active"] == "true", do: "active", else: "failed"
        query |> where([up, ord, op, cred, bro], up.status == ^status)
      else
        query
      end

    query =
      if not is_nil(params["is_membership_currently_active"]) and params["is_membership_currently_active"] == "true" do
        current_time = Time.now_to_epoch() |> div(1000)

        query
        |> where([up, ord, op, cred, bro], up.current_start <= ^current_time and up.current_end >= ^current_time)
      else
        query
      end

    query =
      if not is_nil(params["city_id"]) do
        query |> where([up, ord, op, cred, bro], bro.operating_city == ^params["city_id"])
      else
        query
      end

    query =
      if not is_nil(params["order_id"]) do
        query |> where([up, ord, op, cred, bro], ord.id == ^params["order_id"])
      else
        query
      end

    query =
      if not is_nil(params["phone_number"]) do
        broker_phone_number = params["phone_number"]
        formatted_query = "%#{String.downcase(String.trim(broker_phone_number))}%"
        query |> where([up, ord, op, cred, bro], fragment("LOWER(?) LIKE ?", cred.phone_number, ^formatted_query))
      else
        query
      end

    query =
      if not is_nil(params["time_range_query"]) do
        {start_time, end_time} = Time.get_time_range(params["time_range_query"])

        query
        |> where(
          [up, ord, op, cred, bro],
          fragment("ROUND(extract(epoch from ?))", up.updated_at) >= ^start_time and
            fragment("ROUND(extract(epoch from ?))", up.updated_at) <= ^end_time
        )
      else
        query
      end

    query =
      if not is_nil(params["broker_name"]) do
        broker_name = params["broker_name"]
        formatted_query = "%#{String.downcase(String.trim(broker_name))}%"
        query |> where([up, ord, op, cred, bro], fragment("LOWER(?) LIKE ?", bro.name, ^formatted_query))
      else
        query
      end

    content_query =
      query
      |> order_by([up, ord, op, cred, bro], desc: up.updated_at)
      |> limit(^size)
      |> offset(^((page_no - 1) * size))

    {query, content_query, page_no, size}
  end

  def get_owner_panel_data(params) do
    {query, content_query, page_no, size} = Packages.filter_owner_panel_query(params)

    posts =
      content_query
      |> select_query()
      |> Repo.all()

    total_count =
      query
      |> Repo.aggregate(:count, :id)

    has_more_packages = page_no < Float.ceil(total_count / size)
    {posts, total_count, has_more_packages}
  end

  def build_export_query(params) do
    columns = [
      :phone_number,
      :name,
      :membership_id,
      :membership_status,
      :pg_subscription_id,
      :payment_id,
      :payment_gateway,
      :membership_billing_start_at,
      :membership_billing_end_at,
      :membership_created_at,
      :payment_mode,
      :order_creation_date,
      :payment_status,
      :amount,
      :order_id,
      :autopay_worked_atleast_once,
      :broker_id,
      :assigned_employee_name,
      :assigned_employee_phone_number,
      :assigned_employee_email,
      :polygon
    ]

    query =
      UserPackage
      |> join(:inner, [up], uo in UserOrder, on: up.user_order_id == uo.id)
      |> where([up, uo], uo.status == ^UserOrder.paid_status())
      |> join(:inner, [up, uo], p in Payment, on: p.user_order_id == uo.id)
      |> where([up, uo, p], p.payment_status == ^Payment.captured_status())
      |> join(:inner, [up, uo, p], cred in Credential, on: up.broker_id == cred.broker_id and cred.active == true)
      |> join(:inner, [up, uo, p, cred], bro in Broker, on: up.broker_id == bro.id)
      |> join(:left, [up, uo, p, cred, bro], obem in OwnersBrokerEmployeeMapping, on: obem.broker_id == up.broker_id and obem.active == true)
      |> join(:left, [up, uo, p, cred, bro, obem], emp in EmployeeCredential, on: obem.employees_credentials_id == emp.id)
      |> join(:left, [up, uo, p, cred, bro, obem, emp], pl in Polygon, on: bro.polygon_id == pl.id)

    query =
      if not is_nil(params["month"]) && not is_nil(params["year"]) do
        {start_time, end_time} = Time.get_time_range_for_month(params["month"], params["year"])

        query
        |> where(
          [up, uo, p, cred, bro],
          fragment("ROUND(extract(epoch from ?))", p.updated_at) >= ^start_time and
            fragment("ROUND(extract(epoch from ?))", p.updated_at) <= ^end_time
        )
      else
        query
      end

    records =
      query
      |> order_by([up, uo, p, cred, bro], desc: uo.updated_at)
      |> select_csv_query()
      |> Repo.all()

    [columns]
    |> Stream.concat(
      records
      |> Stream.map(fn record ->
        Enum.map(columns, fn column ->
          format(column, record)
        end)
      end)
    )
    |> CSV.encode()
    |> Enum.to_list()
    |> to_string()
  end

  ##############################################################################
  #  INTERNAL FUNCTION
  ##############################################################################

  defp get_current_start_and_end(package, latest_user_package) when latest_user_package.status == :active or latest_user_package.status == :cancelled do
    current_start =
      latest_user_package.current_end
      |> DateTime.from_unix!()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.shift(days: 1)
      |> Timex.beginning_of_day()
      |> DateTime.to_unix()

    current_end =
      current_start
      |> DateTime.from_unix!()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.shift(days: 1)
      |> Timex.end_of_day()
      |> Timex.shift(days: package.validity_in_days)
      |> DateTime.to_unix()

    {current_start, current_end}
  end

  defp get_current_start_and_end(package, nil) do
    current_start =
      Timex.now()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.beginning_of_day()
      |> DateTime.to_unix()

    current_end =
      current_start
      |> DateTime.from_unix!()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.shift(days: 1)
      |> Timex.end_of_day()
      |> Timex.shift(days: package.validity_in_days)
      |> DateTime.to_unix()

    {current_start, current_end}
  end

  defp get_next_billing_start_and_end(package, latest_user_package) when latest_user_package.status == :active do
    next_billing_start =
      latest_user_package.current_end
      |> DateTime.from_unix!()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.shift(days: 1)
      |> Timex.beginning_of_day()
      |> DateTime.to_unix()

    next_billing_end =
      next_billing_start
      |> DateTime.from_unix!()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.shift(days: 1)
      |> Timex.end_of_day()
      |> Timex.shift(days: package.validity_in_days)
      |> DateTime.to_unix()

    {next_billing_start, next_billing_end}
  end

  defp get_next_billing_start_and_end(_package, nil), do: {nil, nil}

  defp calculate_total_amount(packages) do
    Enum.reduce(packages, 0, fn package, total_amount ->
      package.amount_in_rupees + total_amount
    end)
  end

  defp select_query(query) do
    query
    |> select([up, ord, op, cred, bro, obem, emp, pl], %{
      phone_number: cred.phone_number,
      name: bro.name,
      membership_status: "ACTIVE",
      pg_subscription_id: up.id,
      txn_order_id: op.payment_id,
      payment_gateway: "Billdesk",
      membership_billing_start_at: up.current_start,
      membership_billing_end_at: up.current_end,
      membership_created_at: ord.created_at,
      payment_status: ord.status,
      payment_mode: "UNKNOWN",
      order_id: ord.pg_order_id,
      broker_id: bro.id,
      amount: ord.amount,
      assigned_employee: %{
        name: emp.name,
        phone_number: emp.phone_number,
        email: emp.email,
        ## it is null when ord.created_at is null
        editable: fragment("(EXTRACT(EPOCH FROM current_timestamp) - ?) < ?", ord.created_at, @allowed_assigned_employee_editable_in_sec)
      },
      polygon: pl.name
    })
  end

  defp select_csv_query(query) do
    query
    |> select([up, uo, p, cred, bro, obem, emp, pl], %{
      phone_number: cred.phone_number,
      name: bro.name,
      membership_id: up.id,
      membership_status: up.status,
      pg_subscription_id: up.id,
      payment_id: p.payment_id,
      payment_gateway: "Billdesk",
      membership_billing_start_at: up.current_start,
      membership_billing_end_at: up.current_end,
      membership_created_at: uo.created_at,
      payment_mode: p.payment_method_type,
      order_creation_date: uo.inserted_at,
      payment_status: uo.status,
      amount: p.amount,
      order_id: uo.pg_order_id,
      txn_order_id: uo.pg_order_id,
      autopay_worked_atleast_once: false,
      broker_id: bro.id,
      assigned_employee_name: emp.name,
      assigned_employee_phone_number: emp.phone_number,
      assigned_employee_email: emp.email,
      polygon: pl.name
    })
  end

  defp format(column, record), do: format(record |> Map.get(column))
  defp format(%NaiveDateTime{} = value), do: value |> Timex.Timezone.convert("Etc/UTC") |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.format!("%I:%M %P, %d %b, %Y", :strftime)
  defp format(value) when is_map(value), do: Jason.encode!(value)
  defp format(value) when is_list(value), do: Jason.encode!(value)
  defp format(value), do: String.replace(~s(#{value}), ~s("), "")

  defp get_subscription_status(nil), do: "REJECT"
  # Currently we return reject sothat the subscriptions cannot be cancelled
  # "ACTIVE"
  defp get_subscription_status(_next_billing_start_at), do: "REJECT"

  defp get_order_status("0300", _error_code, _error_type), do: UserOrder.paid_status()
  defp get_order_status("0002", _error_code, _error_type), do: UserOrder.created_status()
  defp get_order_status(_auth_status, _error_code, _error_type), do: UserOrder.failed_status()

  defp get_user_package_status("0300", _error_code, _error_type), do: UserPackage.active_status()
  defp get_user_package_status("0002", _error_code, _error_type), do: UserPackage.pending_status()
  defp get_user_package_status(_auth_status, _error_code, _error_type), do: UserPackage.failed_status()

  defp get_payment_status("0300", _error_code, _error_type), do: Payment.captured_status()
  defp get_payment_status("0002", _error_code, _error_type), do: Payment.pending_status()
  defp get_payment_status(_auth_status, _error_code, _error_type), do: Payment.failed_status()

  defp is_captured?("0300", _error_code, _error_type), do: true
  defp is_captured?(_auth_status, _error_code, _error_type), do: false

  defp maybe_create_invoice(:captured, user_order) do
    Logger.info("create Invoice for : #{user_order.id}")
    Packages.create_invoice(user_order)
  end

  defp maybe_create_invoice(payment_status, user_order) do
    Logger.info("Not Creating Invoice for : #{user_order.id} as payment status is #{inspect(payment_status)}")
    :ok
  end

  defp get_amount(val) do
    {amount, _} = Integer.parse(val)
    amount
  end

  defp updated_user_packages(user_packages, params) do
    user_packages
    |> Enum.reduce([], fn user_package, acc ->
      [user_package |> Map.from_struct() |> Map.merge(params) | acc]
    end)
  end

  defp maybe_send_notification(status, user_order, true) when status in [@captured_status, @failed_status] do
    Logger.info("Send Notification For Subscription Status:#{status} for Order: #{user_order.id}")

    broker_credential =
      Credential
      |> where([cred], cred.broker_id == ^user_order.broker_id)
      |> Repo.all()
      |> Utils.get_active_fcm_credential()

    if not is_nil(broker_credential) do
      {data, type} = get_push_notification_text(status)
      trigger_push_notification(broker_credential, %{"data" => data, "type" => type})
    end
  end

  defp maybe_send_notification(status, _, _) do
    Logger.info("Don't Send Notification For Subscription Status: for Order: #{status}")
    :ok
  end

  defp get_push_notification_text(payment_status) do
    title = "Broker Network Subscriptions"
    message = parse_message_by_payment_status(payment_status)
    intent = "com.dialectic.brokernetworkapp.actions.SUBSCRIPTION.STATUS"
    type = "GENERIC_NOTIFICATION"
    data = %{"title" => title, "message" => message, "intent" => intent}
    {data, type}
  end

  def parse_message_by_payment_status(:captured), do: "Your subscription payment is successfully processed"
  def parse_message_by_payment_status(:failed), do: "Your subscription payment has failed"

  defp trigger_push_notification(broker_credential, notif_data = %{"data" => _data, "type" => _type}) do
    Logger.info("Enqueue Update Subscription Status: #{broker_credential.fcm_id} #{inspect(notif_data)} #{broker_credential.id} #{broker_credential.notification_platform}")

    Exq.enqueue(Exq, "update_subscription_status", BnApis.Notifications.PushNotificationWorker, [
      broker_credential.fcm_id,
      notif_data,
      broker_credential.id,
      broker_credential.notification_platform
    ])
  end
end
