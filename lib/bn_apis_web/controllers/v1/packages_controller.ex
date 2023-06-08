defmodule BnApisWeb.V1.PackagesController do
  use BnApisWeb, :controller

  alias BnApis.Orders.MatchPlusPackage
  alias BnApis.Packages.Payment
  alias BnApis.Accounts.Credential
  alias BnApis.Packages
  alias BnApis.Helpers.Time
  require Logger

  @create_order_base_url Application.get_env(:bn_apis, :create_order_base_url)
  @billdesk_redirect_url Application.get_env(:bn_apis, :billdesk_redirect_url)

  action_fallback(BnApisWeb.FallbackController)

  ##############################################################################
  #  CREATE USER ORDER
  ##############################################################################

  def create_user_order(conn, %{"package_uuid" => package_uuid}) do
    ## creating array to support future usecases...
    user = conn.assigns[:user]
    package_uuids = [package_uuid]

    with packages when is_list(packages) <- fetch_active_package_from_uuid(package_uuids),
         {:ok, user_order} <- Packages.create_user_order(user, packages),
         bd_request <-
           BnPayments.Requests.create_order_payload(
             %{"additional_info1" => "Creating Order for #{length(packages)} packages"},
             "#{user_order.amount_due}.00",
             ## INR Currency Code,
             "356",
             _customer_refid = "#{user["uuid"]}-#{System.os_time(:second)}",
             _subscription_refid = "#{user_order.id}-#{System.os_time(:second)}",
             _start_date = Timex.local() |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.to_date() |> Date.to_string(),
             _end_date = Date.utc_today() |> Date.add(365 * 2) |> Date.to_string(),
             _orderid = user_order.id,
             mandate_required(hd(packages).validity_in_days),
             _frequency = "adho",
             _ru = @billdesk_redirect_url
           ),
         {bd_request, user_order, {:ok, pg_order}} <- {bd_request, user_order, BnPayments.create_order(bd_request)},
         {:ok, _updated_user_order} <-
           Packages.update_user_order(user_order, %{
             pg_order_id: pg_order.bdorderid,
             pg_request: bd_request,
             pg_response: pg_order
           }) do
      conn
      |> put_status(:ok)
      |> json(%{order_id: user_order.id, url: "#{@create_order_base_url}?id=#{user_order.id}"})
    else
      {:error, :invalid_package_uuids} ->
        {:error, "invalid package uuids"}

      {:error, :invalid_payment_gateway_flow} ->
        {:error, "invalid payment gateway flow"}

      {:error, error} ->
        Logger.error("Error Creating User Order: #{inspect(error)}")
        {:error, "unable to create user package"}

      {bd_request, user_order, {:error, pg_response}} ->
        Logger.error("Error Creating User Order at PaymentGateway: #{inspect(pg_response)}")

        Packages.update_user_order(user_order, %{
          status: :failed,
          pg_request: bd_request,
          pg_response: pg_response
        })

        {:error, "unable to create user package"}

      {bd_request, user_order, {:error, changeset, pg_response}} ->
        Logger.error("Error Creating User Order at PaymentGateway: #{inspect(pg_response)} reason: #{inspect(changeset)}")

        Packages.update_user_order(user_order, %{
          status: :failed,
          pg_request: bd_request,
          pg_response: pg_response
        })

        {:error, "unable to create user package"}
    end
  end

  def create_user_order(conn, _params), do: conn |> put_status(:bad_request) |> json(%{message: "Package UUID not found"})

  ##############################################################################
  #  RETRY USER ORDER WITHOUT MANDATE
  ##############################################################################

  def retry_user_order(conn, %{"order_id" => user_order_id}) do
    with {:ok, _} <- Ecto.UUID.cast(user_order_id),
         user_order when not is_nil(user_order) <- Packages.get_user_order_by(%{id: user_order_id}, [:broker, :payments, user_packages: :match_plus_package]),
         credential <- Credential.get_credential_from_broker_id(user_order.broker_id),
         user <- %{"profile" => %{"broker_id" => user_order.broker_id}, "uuid" => credential.uuid},
         packages when is_list(packages) <- [hd(user_order.user_packages).match_plus_package],
         {:ok, user_order} <- Packages.create_user_order(user, packages),
         bd_request <-
           BnPayments.Requests.create_order_payload(
             %{"additional_info1" => "Creating Order for #{length(packages)} packages"},
             "#{user_order.amount_due}.00",
             ## INR Currency Code,
             "356",
             _customer_refid = "#{user["uuid"]}-#{System.os_time(:second)}",
             _subscription_refid = "#{hd(packages).uuid}-#{System.os_time(:second)}",
             _start_date = Timex.local() |> Timex.to_date() |> Date.to_string(),
             _end_date = Date.utc_today() |> Date.add(365 * 2) |> Date.to_string(),
             _orderid = user_order.id,
             "N",
             _frequency = "adho",
             _ru = @billdesk_redirect_url
           ),
         {bd_request, user_order, {:ok, pg_order}} <- {bd_request, user_order, BnPayments.create_order(bd_request)},
         {:ok, _updated_user_order} <-
           Packages.update_user_order(user_order, %{
             pg_order_id: pg_order.bdorderid,
             pg_request: bd_request,
             pg_response: pg_order
           }) do
      conn
      |> put_status(:ok)
      |> json(%{order_id: user_order.id, url: "#{@create_order_base_url}?id=#{user_order.id}"})
    else
      {:error, :invalid_package_uuids} ->
        {:error, "invalid package uuids"}

      {:error, :invalid_payment_gateway_flow} ->
        {:error, "invalid payment gateway flow"}

      {:error, error} ->
        Logger.error("Error Creating User Order: #{inspect(error)}")
        {:error, "unable to create user package"}

      {bd_request, user_order, {:error, pg_response}} ->
        Logger.error("Error Creating User Order at PaymentGateway: #{inspect(pg_response)}")

        Packages.update_user_order(user_order, %{
          status: :failed,
          pg_request: bd_request,
          pg_response: pg_response
        })

        {:error, "unable to create user package"}

      {bd_request, user_order, {:error, _, pg_response}} ->
        Logger.error("Error Creating User Order at PaymentGateway: #{inspect(pg_response)}")

        Packages.update_user_order(user_order, %{
          status: :failed,
          pg_request: bd_request,
          pg_response: pg_response
        })

        {:error, "unable to create user package"}
    end
  end

  ##############################################################################
  #  FETCH USER ORDER
  ##############################################################################

  def fetch_user_order(conn, %{"order_id" => user_order_id}) do
    with {:ok, _} <- Ecto.UUID.cast(user_order_id),
         user_order when not is_nil(user_order) <- Packages.get_user_order_by(%{id: user_order_id}, user_packages: :match_plus_package) do
      response =
        user_order.pg_response
        |> Map.delete("raw_response")
        |> Map.merge(%{"payment_prefs" => hd(user_order.user_packages).match_plus_package.payment_prefs || ["card"]})

      conn
      |> put_status(:ok)
      |> json(response)
    else
      :error ->
        {:error, "invalid order id"}

      nil ->
        {:error, :not_found}
    end
  end

  def fetch_user_order(conn, _params), do: conn |> put_status(:bad_request) |> json(%{message: "Order ID not found"})

  ##############################################################################
  #  FETCH USER ORDER STATUS
  ##############################################################################

  def fetch_user_order_status(conn, %{"order_id" => user_order_id}) do
    with {:ok, _} <- Ecto.UUID.cast(user_order_id),
         user_order when not is_nil(user_order) <- Packages.get_user_order_by(%{id: user_order_id}, [:payments]),
         {:payment_check, payment} when is_nil(payment) or payment.payment_status == :pending <-
           {:payment_check, user_order.payments |> Enum.sort(&(&1.inserted_at > &2.inserted_at)) |> List.first()},
         {:ok, txn} <- user_order_id |> BnPayments.Requests.get_transaction_payload_by_order_id() |> BnPayments.get_transaction(),
         :ok <- Packages.update_payment_from_txn(txn, payment) do
      response = %{
        retry: mandate_failed?(%{payment_data: txn.raw_response}),
        status: get_payment_status(txn.auth_status, txn.transaction_error_code, txn.transaction_error_type),
        reason: txn.raw_response["transaction_error_desc"]
      }

      conn
      |> put_status(:ok)
      |> json(response)
    else
      :error ->
        {:error, "invalid order id"}

      nil ->
        {:error, :not_found}

      {:payment_check, payment} ->
        response = %{
          retry: mandate_failed?(payment),
          status: payment && payment.payment_status,
          reason: payment && payment.payment_data["transaction_error_desc"]
        }

        conn
        |> put_status(:ok)
        |> json(response)

      _error ->
        response = %{
          retry: false,
          status: nil,
          reason: nil
        }

        conn
        |> put_status(:ok)
        |> json(response)
    end
  end

  def fetch_user_order_status(conn, _params), do: conn |> put_status(:bad_request) |> json(%{message: "Order ID not found"})

  ##############################################################################
  #  CANCEL USER PACKAGE
  ##############################################################################

  def cancel(conn, %{"package_uuid" => package_uuid}) do
    user = conn.assigns[:user]
    %{"profile" => %{"broker_id" => broker_id}} = user

    with {:ok, _} <- Ecto.UUID.cast(package_uuid),
         user_package when not is_nil(user_package) <- Packages.get_user_package_by(%{id: package_uuid, status: :active, broker_id: broker_id}),
         {:ok, updated_package} <- Packages.update_user_package(user_package, %{status: :cancelled}) do
      conn
      |> put_status(:ok)
      |> json(%{
        id: updated_package.id,
        status: updated_package.status
      })
    else
      :error -> {:error, "invalid package uuid"}
      nil -> {:error, :not_found}
      error -> error
    end
  end

  ##############################################################################
  #  GET PACKAGES HISTORY
  ##############################################################################

  def get_packages_history(conn, params) do
    user = conn.assigns[:user]
    %{"profile" => %{"broker_id" => broker_id}} = user

    with {:ok, data} <- Packages.get_transaction_history(broker_id, params) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  ##############################################################################
  #  UPDATE GST DETAILS
  ##############################################################################

  def update_gst(conn, %{"id" => user_order_id} = params) do
    user = conn.assigns[:user]
    %{"profile" => %{"broker_id" => broker_id}} = user

    with {:ok, _} <- Ecto.UUID.cast(user_order_id),
         {:user_order, user_order} when not is_nil(user_order) <- {:user_order, Packages.get_user_order_by(%{id: user_order_id, broker_id: broker_id}, payments: :invoice)},
         {:c_payment, c_payment} when not is_nil(c_payment) <- {:c_payment, Enum.find(user_order.payments, fn payment -> not is_nil(payment.invoice) end)},
         true <- order_date_within_limits(c_payment),
         {:ok, updated_invoice} <- Packages.update_invoice_details(c_payment.invoice, user_order_id, params) do
      response = %{
        id: user_order_id,
        invoice_url: updated_invoice.invoice_url,
        message: "GST details have been captured successfully. You will be notified once Invoice is ready!"
      }

      conn
      |> put_status(:ok)
      |> json(response)
    else
      :error ->
        {:error, "invalid order id"}

      {:user_order, nil} ->
        {:error, "No such order found"}

      {:c_payment, nil} ->
        {:error, "Invoice can only be generated for paid orders"}

      false ->
        {:error, "As per new government guidelines, it is not permissible to provide an update on GST after 1 day has passed."}
    end
  end

  ##############################################################################
  #  INTERNAL FUNCTIONS
  ##############################################################################

  defp fetch_active_package_from_uuid(package_uuids) do
    package_uuids
    |> Enum.reduce_while([], fn package_uuid, packages ->
      case MatchPlusPackage.fetch_active_package_from_uuid(package_uuid) do
        nil -> {:halt, {:error, :invalid_package_uuids}}
        package when package.payment_gateway != :billdesk -> {:halt, {:error, :invalid_payment_gateway_flow}}
        package -> {:cont, [package | packages]}
      end
    end)
  end

  ## Currently Mark it "Y" for 3 Months...
  defp mandate_required(90), do: "Y"
  defp mandate_required(_), do: "N"

  defp order_date_within_limits(c_payment) do
    current_time = Timex.now() |> DateTime.to_unix()
    end_of_next_day =
      c_payment.created_at
      |> DateTime.from_unix!()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.end_of_day()
      |> Timex.shift(days: 1)
      |> DateTime.to_unix()

    cond do
      current_time < end_of_next_day ->
        true

      true ->
        false
    end
  end

  defp mandate_failed?(nil), do: false

  defp mandate_failed?(latest_payment) do
    payment_data = latest_payment.payment_data
    mandate = payment_data["mandate"]
    status = mandate && mandate["status"]
    verification_error_code = mandate && mandate["verification_error_code"]
    if status == "rejected" and verification_error_code == "MNAIE0012", do: true, else: false
  end

  defp get_payment_status("0300", "TRS0000", "success"), do: Payment.captured_status()
  defp get_payment_status("0002", _error_code, _error_type), do: Payment.pending_status()
  defp get_payment_status(_auth_status, _error_code, _error_type), do: Payment.failed_status()
end
