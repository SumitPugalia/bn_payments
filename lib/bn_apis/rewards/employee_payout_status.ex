defmodule BnApis.Rewards.EmployeePayoutStatus do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Rewards.EmployeePayoutStatus
  alias BnApis.Rewards.EmployeePayout

  schema "employee_payout_status" do
    field(:status, :string)
    field(:razorpay_data, :map)
    belongs_to(:rewards_employee_payout, EmployeePayout)
    timestamps()
  end

  @required [:status, :rewards_employee_payout_id]
  @optional [:razorpay_data]

  @doc false
  def changeset(employee_payout_status, attrs) do
    employee_payout_status
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:rewards_employee_payout_id)
  end

  def create_employee_payout_status!(
        employee_payout,
        status,
        razorpay_data
      ) do
    changeset =
      EmployeePayoutStatus.changeset(%EmployeePayoutStatus{}, %{
        rewards_employee_payout_id: employee_payout.id,
        status: status,
        razorpay_data: razorpay_data
      })

    employee_payout_status = Repo.insert!(changeset)
    employee_payout_status
  end
end
