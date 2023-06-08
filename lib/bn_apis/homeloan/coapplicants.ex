defmodule BnApis.Homeloan.Coapplicants do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Homeloan.Lead
  alias BnApis.Homeloan.Coapplicants

  schema "loan_coapplicants" do
    field(:name, :string)
    field(:employment_type, :integer)
    field(:resident, :string)
    field(:gender, :string)
    field(:cibil_score, :float)
    field(:date_of_birth, :integer)
    field(:income_details, :integer)
    field(:additional_income, :integer)
    field(:existing_loan_emi, :integer)
    field(:active, :boolean, default: true)
    field(:email_id, :string)

    belongs_to :homeloan_lead, Lead
    timestamps()
  end

  @required [:homeloan_lead_id, :name, :active]
  @optional [:employment_type, :resident, :gender, :cibil_score, :date_of_birth, :income_details, :additional_income, :existing_loan_emi, :email_id]

  @doc false
  def changeset(coapplicant, attrs) do
    coapplicant
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
    |> foreign_key_constraint(:homeloan_lead_id)
  end

  def add_coapplicant(params) do
    Coapplicants.changeset(%Coapplicants{}, %{
      homeloan_lead_id: params["homeloan_lead_id"],
      name: params["name"],
      employment_type: params["employment_type"],
      resident: params["resident"],
      gender: params["gender"],
      cibil_score: params["cibil_score"],
      date_of_birth: params["date_of_birth"],
      income_details: params["income_details"],
      additional_income: params["additional_income"],
      existing_loan_emi: params["existing_loan_emi"],
      active: true,
      email_id: params["email_id"]
    })
    |> Repo.insert()
  end

  def update_coapplicant(coapplicant, params) do
    case coapplicant do
      nil ->
        {:error, :not_found}

      coapplicant ->
        Coapplicants.changeset(coapplicant, params) |> Repo.update()
    end
  end

  def get_coapplicants_for_lead(lead_id) do
    Coapplicants
    |> where([ca], ca.active == true and ca.homeloan_lead_id == ^lead_id)
    |> Repo.all()
    |> Enum.map(fn coapplicant ->
      %{
        "coapplicant_id" => coapplicant.id,
        "name" => coapplicant.name,
        "employment_type" => coapplicant.employment_type,
        "resident" => coapplicant.resident,
        "gender" => coapplicant.gender,
        "cibil_score" => coapplicant.cibil_score,
        "date_of_birth" => coapplicant.date_of_birth,
        "income_details" => coapplicant.income_details,
        "additional_income" => coapplicant.additional_income,
        "existing_loan_emi" => coapplicant.existing_loan_emi,
        "email_id" => coapplicant.email_id
      }
    end)
  end
end
