defmodule BnApis.Organizations.BrokerCommission do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApis.Organizations.BrokerCommission
  alias BnApis.Helpers.AuditedRepo
  alias BnApis.Homeloan.Lead

  schema "broker_commission" do
    field(:homeloan_by_bn_commission, :float)
    field(:homeloan_by_self_commission, :float)
    field(:commercial_loan_by_bn_commission, :float)
    field(:commercial_loan_by_self_commission, :float)
    field(:mortgage_loan_by_bn_commission, :float)
    field(:mortgage_loan_by_self_commission, :float)
    field(:business_loan, :float)
    field(:personal_loan, :float)
    field(:other_loan_type, :map)

    belongs_to :broker, Broker

    timestamps()
  end

  @required [
    :homeloan_by_bn_commission,
    :homeloan_by_self_commission,
    :commercial_loan_by_bn_commission,
    :commercial_loan_by_self_commission,
    :mortgage_loan_by_bn_commission,
    :mortgage_loan_by_self_commission,
    :business_loan,
    :personal_loan,
    :broker_id
  ]

  @optional [
    :other_loan_type
  ]

  @percentage_multiplier 0.01

  @doc false
  def changeset(lead, attrs) do
    lead
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
  end

  def add_broker_commission_detail(
        params = %{
          "homeloan_by_bn_commission" => homeloan_by_bn_commission,
          "homeloan_by_self_commission" => homeloan_by_self_commission,
          "commercial_loan_by_bn_commission" => commercial_loan_by_bn_commission,
          "commercial_loan_by_self_commission" => commercial_loan_by_self_commission,
          "mortgage_loan_by_bn_commission" => mortgage_loan_by_bn_commission,
          "mortgage_loan_by_self_commission" => mortgage_loan_by_self_commission,
          "business_loan" => business_loan,
          "personal_loan" => personal_loan
        },
        broker_id
      ) do
    BrokerCommission.changeset(%BrokerCommission{}, %{
      "homeloan_by_bn_commission" => homeloan_by_bn_commission,
      "homeloan_by_self_commission" => homeloan_by_self_commission,
      "commercial_loan_by_bn_commission" => commercial_loan_by_bn_commission,
      "commercial_loan_by_self_commission" => commercial_loan_by_self_commission,
      "mortgage_loan_by_bn_commission" => mortgage_loan_by_bn_commission,
      "mortgage_loan_by_self_commission" => mortgage_loan_by_self_commission,
      "business_loan" => business_loan,
      "personal_loan" => personal_loan,
      "other_loan_type" => params["other_loan_type"],
      "broker_id" => broker_id
    })
    |> Repo.insert()
  end

  def get_broker_commission_detail(broker_id) do
    BrokerCommission
    |> where([b], b.broker_id == ^broker_id)
    |> select([b], %{
      "homeloan_by_bn_commission" => b.homeloan_by_bn_commission,
      "homeloan_by_self_commission" => b.homeloan_by_self_commission,
      "commercial_loan_by_bn_commission" => b.commercial_loan_by_bn_commission,
      "commercial_loan_by_self_commission" => b.commercial_loan_by_self_commission,
      "mortgage_loan_by_bn_commission" => b.mortgage_loan_by_bn_commission,
      "mortgage_loan_by_self_commission" => b.mortgage_loan_by_self_commission,
      "business_loan" => b.business_loan,
      "personal_loan" => b.personal_loan,
      "other_loan_type" => b.other_loan_type,
      "broker_id" => b.broker_id
    })
    |> Repo.one()
  end

  defp get_display_text_string(processing_by_self, processing_by_bn) do
    "#{processing_by_bn}% if processed by 4B\n#{processing_by_self}% if processed by self"
  end

  def structure_broker_commission_remote_config(broker_commission) do
    [
      %{
        "display_name" => "Home Loan",
        "processing_by_self" => broker_commission["homeloan_by_self_commission"],
        "processing_by_bn" => broker_commission["homeloan_by_bn_commission"],
        "display_text" => get_display_text_string(broker_commission["homeloan_by_self_commission"], broker_commission["homeloan_by_bn_commission"])
      },
      %{
        "display_name" => "Commercial Loan",
        "processing_by_self" => broker_commission["commercial_loan_by_self_commission"],
        "processing_by_bn" => broker_commission["commercial_loan_by_bn_commission"],
        "display_text" => get_display_text_string(broker_commission["commercial_loan_by_self_commission"], broker_commission["commercial_loan_by_bn_commission"])
      },
      %{
        "display_name" => "Mortgage Loan",
        "processing_by_self" => broker_commission["mortgage_loan_by_self_commission"],
        "processing_by_bn" => broker_commission["mortgage_loan_by_bn_commission"],
        "display_text" => get_display_text_string(broker_commission["mortgage_loan_by_self_commission"], broker_commission["mortgage_loan_by_bn_commission"])
      },
      %{
        "display_name" => "Business Loan",
        "processing_by_self" => broker_commission["business_loan"],
        "processing_by_bn" => broker_commission["business_loan"],
        "display_text" => "#{broker_commission["business_loan"]}% if processed by 4B or self"
      },
      %{
        "display_name" => "Personal Loan",
        "processing_by_self" => broker_commission["personal_loan"],
        "processing_by_bn" => broker_commission["personal_loan"],
        "display_text" => "#{broker_commission["business_loan"]}% if processed by 4B or self"
      }
    ]
    |> maybe_append_other_loan(broker_commission["other_loan_type"])
  end

  defp maybe_append_other_loan(commission_struct, other_loan) do
    if is_nil(other_loan) do
      commission_struct
    else
      commission_struct ++
        [
          %{
            "display_name" => other_loan["name"],
            "processing_by_self" => other_loan["processing_by_self"],
            "processing_by_bn" => other_loan["processing_by_bn"],
            "display_text" => "#{other_loan["processing_by_self"]}% if processed by 4B or self"
          }
        ]
    end
  end

  def update_broker_commission_detail(broker_id, params, user_map) do
    broker_commission = BrokerCommission |> Repo.get_by(broker_id: broker_id)

    case broker_commission do
      nil ->
        {:error, :not_found}

      broker_commission ->
        broker_commission
        |> BrokerCommission.changeset(params)
        |> AuditedRepo.update(user_map)
    end
  end

  def calculate_broker_commission(loan_amount, loan_type, broker_id, processing_type) when processing_type == "self" do
    broker_commission = get_broker_commission_detail(broker_id)

    case String.downcase(loan_type) do
      "home loan" -> loan_amount * broker_commission["homeloan_by_self_commission"] * @percentage_multiplier
      "commercial loan" -> loan_amount * broker_commission["commercial_loan_by_self_commission"] * @percentage_multiplier
      "business loan" -> loan_amount * broker_commission["business_loan"] * @percentage_multiplier
      "mortgage loan" -> loan_amount * broker_commission["mortgage_loan_by_self_commission"] * @percentage_multiplier
      "personal loan" -> loan_amount * broker_commission["personal_loan"] * @percentage_multiplier
      _ -> loan_amount * (broker_commission["other_loan_type"] |> Map.get("processing_by_self") || 0) * @percentage_multiplier
    end
  end

  def calculate_broker_commission(loan_amount, loan_type, broker_id, processing_type) when processing_type == "bn" do
    broker_commission = get_broker_commission_detail(broker_id)

    case String.downcase(loan_type) do
      "home loan" -> loan_amount * broker_commission["homeloan_by_bn_commission"] * @percentage_multiplier
      "commercial loan" -> loan_amount * broker_commission["commercial_loan_by_bn_commission"] * @percentage_multiplier
      "business loan" -> loan_amount * broker_commission["business_loan"] * @percentage_multiplier
      "mortgage loan" -> loan_amount * broker_commission["mortgage_loan_by_bn_commission"] * @percentage_multiplier
      "personal loan" -> loan_amount * broker_commission["personal_loan"] * @percentage_multiplier
      _ -> loan_amount * (broker_commission["other_loan_type"] |> Map.get("processing_by_bn") || 0) * @percentage_multiplier
    end
  end

  def calculate_broker_commission(_loan_amount, _loan_type, _broker_id, _process_type), do: nil

  def get_loan_types(broker_id) do
    Lead.loan_types() |> Enum.filter(fn l -> is_commission_available(l, broker_id) end)
  end

  def is_commission_available(loan_type, broker_id) do
    broker_commission = get_broker_commission_detail(broker_id)

    case String.downcase(loan_type) do
      "home loan" -> (broker_commission["homeloan_by_bn_commission"] == 0 and broker_commission["homeloan_by_self_commission"] == 0) == false
      "commercial loan" -> (broker_commission["commercial_loan_by_bn_commission"] == 0 and broker_commission["commercial_loan_by_self_commission"] == 0) == false
      "business loan" -> broker_commission["business_loan"] == 0 == false
      "mortgage loan" -> (broker_commission["mortgage_loan_by_bn_commission"] == 0 and broker_commission["mortgage_loan_by_self_commission"] == 0) == false
      "personal loan" -> broker_commission["personal_loan"] == 0 == false
      _ -> false
    end
  end

  def maybe_append_other_loan_type(loan_types_list, broker_id) do
    broker_commission = get_broker_commission_detail(broker_id)

    if is_nil(broker_commission["other_loan_type"]) do
      loan_types_list
    else
      loan_types_list ++ [broker_commission["other_loan_type"]["name"]]
    end
  end
end
