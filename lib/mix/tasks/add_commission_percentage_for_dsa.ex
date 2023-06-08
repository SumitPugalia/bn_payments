defmodule Mix.Tasks.AddCommissionPercentageForDsa do
  import Ecto.Query

  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Helpers.Utils

  def run(_) do
    Mix.Task.run("app.start", [])
    disbursements = get_all_loan_disbursement()

    disbursements
    |> Enum.each(fn disbursement ->
      commission_percentage = add_commission_percentage(disbursement)

      case disbursement |> LoanDisbursement.changeset(%{commission_percentage: commission_percentage}) |> Repo.update() do
        {:ok, _} ->
          IO.puts("successfully updated for disbursement_id:#{disbursement.id}")

        {:error, e} ->
          IO.puts("error occurred in disubursement_id: #{disbursement.id}")
          IO.puts(e)
      end
    end)
  end

  def get_all_loan_disbursement() do
    LoanDisbursement
    |> where([l], not is_nil(l.loan_commission) and not is_nil(l.loan_file_id) and is_nil(l.commission_percentage) and l.active == true)
    |> Repo.all()
    |> Repo.preload(loan_file: :bank)
  end

  def add_commission_percentage(disbursement) do
    case disbursement.loan_file.bank.commission_on do
      :sanctioned_amount ->
        loan_commission_percentage = trunc(disbursement.loan_commission * 100) / disbursement.loan_file.sanctioned_amount
        Utils.float_with_digits(loan_commission_percentage, 3)

      :disbursement_amount ->
        loan_commission_percentage = trunc(disbursement.loan_commission * 100) / disbursement.loan_disbursed
        Utils.float_with_digits(loan_commission_percentage, 3)

      _ ->
        nil
    end
  end
end
