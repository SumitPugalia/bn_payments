defmodule BnApis.Stories.InvoiceItem do
  use Ecto.Schema
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Helpers.AuditedRepo
  alias BnApis.Stories.Schema.InvoiceItem
  alias BnApis.Stories.Schema.Invoice, as: InvoiceSchema
  alias BnApis.BookingRewards

  @booking_reward_invoice_type InvoiceSchema.type_reward()

  def add_invoice_item(nil, _invoice_id, _user_map), do: {:ok, nil}

  def add_invoice_item(
        params = %{
          "customer_name" => customer_name,
          "unit_number" => unit_number,
          "wing_name" => wing_name,
          "building_name" => building_name,
          "agreement_value" => agreement_value,
          "brokerage_amount" => brokerage_amount
        },
        invoice_id,
        user_map
      ) do
    brokerage_percent = Map.get(params, "brokerage_percent")

    customer_name = String.trim(customer_name)
    unit_number = String.trim(unit_number)
    wing_name = String.trim(wing_name)
    building_name = String.trim(building_name)

    %InvoiceItem{}
    |> InvoiceItem.changeset(%{
      customer_name: customer_name,
      unit_number: unit_number,
      wing_name: wing_name,
      building_name: building_name,
      active: true,
      agreement_value: agreement_value,
      brokerage_amount: brokerage_amount,
      brokerage_percent: brokerage_percent,
      invoice_id: invoice_id
    })
    |> AuditedRepo.insert(user_map)
    |> case do
      {:ok, invoice_item} ->
        {:ok, create_invoice_item_map(invoice_item)}

      {:error, error} ->
        {:error, error}
    end
  end

  def add_invoice_item(_params, _invoice_id, _user_map), do: {:error, "Invalid params for invoice item."}

  def update_invoice_item(nil, _invoice_id, _user_map), do: {:ok, nil}

  def update_invoice_item(
        params = %{
          "customer_name" => customer_name,
          "unit_number" => unit_number,
          "wing_name" => wing_name,
          "building_name" => building_name,
          "active" => active,
          "agreement_value" => agreement_value,
          "brokerage_amount" => brokerage_amount
        },
        invoice_id,
        user_map
      ) do
    id = Map.get(params, "id")
    brokerage_percent = Map.get(params, "brokerage_percent")

    customer_name = String.trim(customer_name)
    unit_number = String.trim(unit_number)
    wing_name = String.trim(wing_name)
    building_name = String.trim(building_name)

    invoice_item = fetch_invoice_item_by_id(id)

    cond do
      is_nil(invoice_item) ->
        create_or_throw_error_for_invoice_item(id, params, invoice_id, user_map)

      invoice_item ->
        invoice_item
        |> InvoiceItem.changeset(%{
          customer_name: customer_name,
          unit_number: unit_number,
          wing_name: wing_name,
          building_name: building_name,
          active: active,
          agreement_value: agreement_value,
          brokerage_amount: brokerage_amount,
          brokerage_percent: brokerage_percent
        })
        |> AuditedRepo.update(user_map)
        |> case do
          {:ok, invoice_item} ->
            {:ok, create_invoice_item_map(invoice_item)}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  def update_invoice_item(_params, _invoice_id, _user_map), do: {:error, "Invalid params for invoice item."}

  def get_active_invoice_items(nil), do: []

  def get_active_invoice_items(invoice = %{type: @booking_reward_invoice_type}) do
    invoice = BookingRewards.put_items_in_invoice(invoice)
    invoice.invoice_items
  end

  def get_active_invoice_items(invoice) do
    InvoiceItem
    |> where([it], it.active == true and it.invoice_id == ^invoice.id)
    |> Repo.all()
    |> Enum.map(&create_invoice_item_map(&1))
  end

  def get_active_invoice_items_records(nil), do: []

  def get_active_invoice_items_records(invoice_id) do
    InvoiceItem
    |> where([it], it.active == true and it.invoice_id == ^invoice_id)
    |> Repo.all()
  end

  def deactivate_invoice_item(invoice_item_id, user_map) do
    case fetch_invoice_item_by_id(invoice_item_id) do
      nil ->
        {:ok, nil}

      invoice_item ->
        invoice_item
        |> InvoiceItem.changeset(%{active: false})
        |> AuditedRepo.update(user_map)
    end
  end

  ## Private APIs
  defp fetch_invoice_item_by_id(nil), do: nil
  defp fetch_invoice_item_by_id(id), do: Repo.get_by(InvoiceItem, id: id)

  defp create_or_throw_error_for_invoice_item(nil, params, invoice_id, user_map),
    do: add_invoice_item(params, invoice_id, user_map)

  defp create_or_throw_error_for_invoice_item(_id, _params, _invoice_id, _user_map),
    do: {:error, "Invoice item not found"}

  defp parse_brokerage_percent(nil), do: nil

  defp parse_brokerage_percent(brokerage_percent),
    do: if(is_float(brokerage_percent), do: Float.round(brokerage_percent, 2), else: brokerage_percent)

  defp create_invoice_item_map(nil), do: nil

  defp create_invoice_item_map(invoice_item) do
    brokerage_percent = parse_brokerage_percent(invoice_item.brokerage_percent)

    %{
      "id" => invoice_item.id,
      "uuid" => invoice_item.uuid,
      "customer_name" => invoice_item.customer_name,
      "unit_number" => invoice_item.unit_number,
      "wing_name" => invoice_item.wing_name,
      "building_name" => invoice_item.building_name,
      "active" => invoice_item.active,
      "agreement_value" => invoice_item.agreement_value,
      "brokerage_percent" => brokerage_percent,
      "brokerage_amount" => invoice_item.brokerage_amount,
      "invoice_id" => invoice_item.invoice_id
    }
  end
end
