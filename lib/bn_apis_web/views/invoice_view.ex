defmodule BnApisWeb.InvoiceView do
  use BnApisWeb, :view
  alias BnApis.Stories.Schema.Invoice
  alias BnApisWeb.ChangesetView
  alias BnApis.Helpers.{S3Helper, ApplicationHelper}

  @reward_type Invoice.type_reward()
  @imgix_domain ApplicationHelper.get_imgix_domain()

  def render("mark_invoice_to_be_paid.json", %{failures: failures}) do
    map =
      Enum.reduce(failures, %{}, fn
        {key, %Ecto.Changeset{} = value}, map ->
          value = ChangesetView.parse(ChangesetView.translate_errors(value))
          Map.put(map, key, value)

        {key, value}, map ->
          Map.put(map, key, value)
      end)

    if Map.keys(map) == [] do
      %{message: "success"}
    else
      %{message: "Some entries failed.", failures: map}
    end
  end

  def get_brokerage_percent_text(_invoice_item, @reward_type), do: ""

  def get_brokerage_percent_text(invoice_item, _type) do
    "at " <> :erlang.float_to_binary(invoice_item.brokerage_amount / invoice_item.agreement_value * 100, decimals: 2) <> "% brokerage."
  end

  def action_type(@reward_type), do: "booking"
  def action_type(_type), do: "sale"

  def parse_signature(nil), do: nil
  def parse_signature(""), do: ""

  def parse_signature(signature) do
    String.contains?(signature, @imgix_domain)
    |> case do
      true ->
        signature

      false ->
        S3Helper.get_imgix_url(signature)
    end
  end

  def gst?(gst?, value) do
    if gst?, do: value, else: "nil"
  end

  def upcase(nil), do: ""
  def upcase(str), do: String.upcase(str)

  def set_default(nil), do: "NA"
  def set_default(""), do: "NA"
  def set_default(str), do: upcase(str)

  def float_round(nil), do: nil

  def float_round(value) do
    case is_integer(value) do
      true -> value
      false -> Float.round(value, 2) |> :erlang.float_to_binary(decimals: 2)
    end
  end

  def get_tds_percentage(is_tds_valid) do
    if(is_tds_valid == true, do: "20%", else: "5%")
  end

  def broker_network_address() do
    """
    Ground Floor, A UNIT OF FLEUR HOTELS PVT LTD, LEMON TREE<br/>
    PREMIER HOTEL, Behind RBL Bank Marol Andheri East, Mumbai,<br/>
    Mumbai Suburban, Maharashtra, 400059<br/>
    <br/><br/>
    GST: 27AABCZ6271C1ZB<br/>
    PAN: AABCZ6271C<br/>
    RERA: A51900031168<br/>
    Place of Supply: Maharastra<br/>
    State Code: 27<br/>
    """
  end
end
