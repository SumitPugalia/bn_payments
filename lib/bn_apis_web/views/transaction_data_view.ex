defmodule BnApisWeb.TransactionDataView do
  use BnApisWeb, :view
  alias BnApisWeb.TransactionDataView
  alias BnApis.Helpers.Time

  def render("index.json", %{transactions_data: transactions_data}) do
    %{data: render_many(transactions_data, TransactionDataView, "transaction_data.json")}
  end

  def render("index.json", %{duplicate_buildings: duplicate_buildings}) do
    %{data: render_many(duplicate_buildings, TransactionDataView, "duplicate_building.json", as: :duplicate_building)}
  end

  def render("show.json", %{transaction_data: transaction_data}) do
    %{data: render_one(transaction_data, TransactionDataView, "transaction_data.json")}
  end

  def render("show.json", %{transaction: transaction}) do
    %{data: render_one(transaction, TransactionDataView, "transaction.json", as: :transaction)}
  end

  def render("transaction_data.json", %{transaction_data: transaction_data}) do
    %{
      id: transaction_data.id,
      registration_date: transaction_data.registration_date |> Time.naive_to_epoch(),
      amount: transaction_data.amount |> Decimal.to_float(),
      doc_html: transaction_data.doc_html,
      doc_number: transaction_data.doc_number,
      sro_id: transaction_data.sro_id,
      doc_type_id: transaction_data.doc_type_id
    }
  end

  def render("duplicate_building.json", %{duplicate_building: duplicate_building}) do
    %{
      name: duplicate_building.name,
      count: duplicate_building.count
    }
  end

  def render("processed_transaction_data.json", %{transaction: transaction}) do
    %{
      data: render_one(transaction, TransactionDataView, "transaction.json", as: :transaction)
    }
  end

  def render("unprocessed_transaction_data.json", %{transaction_data: transaction_data}) do
    extras = %{
      total_processed_documents: transaction_data.total_processed_documents,
      today_processed_documents: transaction_data.today_processed_documents
    }

    transaction_data = render_one(transaction_data, TransactionDataView, "transaction_data.json")
    transaction_data = transaction_data |> Map.merge(extras)

    %{
      data: transaction_data
    }
  end

  def render("transaction.json", %{transaction: transaction}) do
    transaction_building = transaction.transaction_building
    transaction_data = transaction.transaction_data

    %{
      id: transaction.id,
      flat_no: transaction.flat_no,
      floor_no: transaction.floor_no,
      transaction_type: transaction.transaction_type,
      transaction_data_id: transaction.transaction_data_id,
      area: transaction.area,
      price: transaction.price,
      rent: transaction.rent,
      tenure_for_rent: transaction.tenure_for_rent,
      doc_html: transaction_data.doc_html,
      building_info: %{
        id: transaction_building.id,
        name: transaction_building.name,
        address: transaction_building.address,
        locality: transaction_building.locality,
        place_id: transaction_building.place_id
      }
    }
  end

  def render("districts.json", %{districts_data: districts_data}) do
    %{data: render_many(districts_data, TransactionDataView, "district.json", as: :district)}
  end

  def render("district.json", %{district: district}) do
    %{id: district.id, name: district.name, address: district.address}
  end
end
