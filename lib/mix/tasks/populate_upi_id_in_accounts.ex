defmodule Mix.Tasks.PopulateUpiIdInAccounts do
  use Mix.Task
  import Ecto.Query
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Accounts
  alias BnApis.Accounts.{Credential, EmployeeCredential}

  @shortdoc "Add Upi Id to account tables"
  def run(_) do
    Mix.Task.run("app.start", [])
    add_upi_id_to_employee_credentials()
    add_upi_id_to_credentials()
  end

  def add_upi_id_to_credentials() do
    Credential
    |> where([c], is_nil(c.upi_id) and not is_nil(c.razorpay_fund_account_id))
    |> Repo.all()
    |> Enum.each(fn credential ->
      {_upi_presence, vpa_address} = Accounts.fetch_upi_id(credential.razorpay_contact_id, credential.razorpay_fund_account_id)

      save_upi_in_credential(credential, vpa_address)
      Process.sleep(1000)
    end)
  end

  def add_upi_id_to_employee_credentials() do
    EmployeeCredential
    |> where([ec], is_nil(ec.upi_id) and not is_nil(ec.razorpay_fund_account_id))
    |> Repo.all()
    |> Enum.each(fn employee_credential ->
      {_upi_presence, vpa_address} = Accounts.fetch_upi_id(employee_credential.razorpay_contact_id, employee_credential.razorpay_fund_account_id)

      save_upi_in_employee_credential(employee_credential, vpa_address)
      Process.sleep(1000)
    end)
  end

  defp save_upi_in_credential(_credential, nil), do: nil

  defp save_upi_in_credential(credential, upi_id) do
    try do
      credential |> Credential.changeset(%{"upi_id" => upi_id}) |> Repo.update!()
    rescue
      _ ->
        nil
    end
  end

  defp save_upi_in_employee_credential(_employee_credential, nil), do: nil

  defp save_upi_in_employee_credential(employee_credential, upi_id) do
    try do
      employee_credential |> cast(%{"upi_id" => upi_id}, [:upi_id]) |> Repo.update!()
    rescue
      _ ->
        nil
    end
  end
end
