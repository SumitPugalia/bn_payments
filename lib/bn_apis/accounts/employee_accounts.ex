defmodule BnApis.Accounts.EmployeeAccounts do
  @moduledoc """
  The EmployeeAccounts context.
  """

  alias BnApis.Repo
  alias BnApis.Accounts
  alias BnApis.Accounts.{EmployeeCredential, EmployeeRole}

  alias BnApis.Helpers.{
    ApplicationHelper,
    ExternalApiHelper,
    AuditedRepo
  }

  def validate_upi(upi_id) do
    attestr_auth_key = ApplicationHelper.get_attestr_auth_key()

    {_status_code, attestr_response} = ExternalApiHelper.validate_upi(upi_id, attestr_auth_key)

    if attestr_response["valid"] do
      {true, attestr_response["name"]}
    else
      {false, attestr_response["message"]}
    end
  end

  def update_employee_details(
        uuid,
        name,
        phone_number,
        employee_role_id,
        email,
        employee_code,
        city_id,
        reporting_manager_id,
        access_city_ids,
        country_code,
        vertical_id
      ) do
    employee_credential = EmployeeCredential.fetch_employee(uuid)

    cond do
      is_nil(employee_credential) ->
        {:error, "Employee not found"}

      employee_credential ->
        Repo.transaction(fn ->
          try do
            {:ok, changeset} =
              employee_credential
              |> EmployeeCredential.update_employee_profile_changeset(%{
                "name" => name,
                "phone_number" => phone_number,
                "country_code" => country_code,
                "employee_role_id" => employee_role_id,
                "email" => email,
                "employee_code" => employee_code,
                "city_id" => city_id,
                "reporting_manager_id" => reporting_manager_id,
                "access_city_ids" => access_city_ids,
                "vertical_id" => vertical_id
              })
              |> Repo.update()

            maybe_register_employee_on_sendbird(employee_credential, employee_role_id)

            {:ok, changeset}
          rescue
            err ->
              Repo.rollback(Exception.message(err))
          end
        end)

      true ->
        {:error, "Employee not found"}
    end
  end

  def maybe_register_employee_on_sendbird(employee_credential, employee_role_id) do
    cond do
      employee_role_id == EmployeeRole.hl_agent().id ->
        Exq.enqueue(Exq, "sendbird", BnApis.RegisterHlAgentOnSendbird, [
          EmployeeCredential.get_sendbird_payload_hl(employee_credential)
        ])

      employee_role_id == EmployeeRole.dsa_agent().id ->
        Exq.enqueue(Exq, "sendbird", BnApis.RegisterHlAgentOnSendbird, [
          EmployeeCredential.get_sendbird_payload_dsa_agent(employee_credential)
        ])

      true ->
        nil
    end
  end

  def update_upi_id(phone_number, upi_id, user_map) do
    employee_credential = EmployeeCredential.fetch_employee_credential(phone_number, "+91")

    cond do
      is_nil(employee_credential) ->
        {:error, "Employee not found"}

      employee_credential ->
        auth_key = ApplicationHelper.get_razorpay_auth_key()

        {razorpay_contact_id, contact_response} =
          if is_nil(employee_credential.razorpay_contact_id) do
            {_status_code, contact_response} =
              ExternalApiHelper.create_razorpay_contact_id(
                employee_credential.phone_number,
                employee_credential.id,
                auth_key
              )

            {contact_response["id"], contact_response}
          else
            {employee_credential.razorpay_contact_id, nil}
          end

        {_status_code, fund_response} =
          ExternalApiHelper.create_razorpay_fund_account_id(
            razorpay_contact_id,
            upi_id,
            auth_key
          )

        razorpay_fund_account_id = fund_response["id"]

        result =
          employee_credential
          |> EmployeeCredential.razorpay_changeset(
            upi_id,
            razorpay_contact_id,
            razorpay_fund_account_id
          )
          |> AuditedRepo.update(user_map)

        if not is_nil(razorpay_fund_account_id) and not is_nil(razorpay_contact_id) do
          result
        else
          channel = ApplicationHelper.get_slack_channel()

          ApplicationHelper.notify_on_slack(
            "Razorpay issue: <@U02JG7END9B>, <@U03MCEL5WU8> fund_response: #{inspect(fund_response)}, contact_response: #{inspect(contact_response)}",
            channel
          )

          {:error, "Our payment partner is facing some issues, try after 5 min."}
        end

      true ->
        {:error, "Employee not found"}
    end
  end

  def check_upi_id(phone_number) do
    employee_credential = EmployeeCredential.fetch_employee_credential(phone_number, "+91")

    cond do
      is_nil(employee_credential) ->
        {:error, "Employee not found"}

      employee_credential ->
        Accounts.fetch_upi_id(employee_credential.razorpay_contact_id, employee_credential.razorpay_fund_account_id)

      true ->
        {:error, "Employee not found"}
    end
  end
end
