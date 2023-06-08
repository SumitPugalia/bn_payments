defmodule BnApisWeb.TransactionView do
  use BnApisWeb, :view
  alias BnApisWeb.TransactionView
  alias BnApis.Helpers.Time

  def render("transactions.json", %{transactions: transactions}) do
    %{data: render_many(transactions, TransactionView, "transaction.json")}
  end

  def render("transaction.json", %{transaction: transaction}) do
    transaction_building = transaction.transaction_building

    %{
      id: transaction.id,
      flat_no: transaction.flat_no,
      floor_no: transaction.floor_no,
      transaction_type: transaction.transaction_type,
      transaction_data_id: transaction.transaction_data_id,
      registration_date: transaction.registration_date |> Time.naive_to_epoch(),
      area: transaction.area,
      price: transaction.price,
      rent: transaction.rent,
      tenure_for_rent: transaction.tenure_for_rent,
      building_info: %{
        id: transaction_building.id,
        name: transaction_building.name,
        address: transaction_building.address,
        locality: transaction_building.locality,
        place_id: transaction_building.place_id
      }
    }
  end
end
