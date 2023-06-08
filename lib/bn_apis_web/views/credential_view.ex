defmodule BnApisWeb.CredentialView do
  use BnApisWeb, :view
  alias BnApisWeb.CredentialView
  alias BnApis.Helpers.S3Helper
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Repo

  def render("index.json", %{credentials: credentials}) do
    %{data: render_many(credentials, CredentialView, "credential.json")}
  end

  def render("show.json", %{credential: credential}) do
    %{data: render_one(credential, CredentialView, "credential.json")}
  end

  def render("credential.json", %{credential: credential}) do
    %{
      id: credential.id,
      uuid: credential.uuid,
      email: credential.email,
      phone_number: credential.phone_number,
      phone_number_verified: credential.phone_number_verified
    }
  end

  def render("verify_otp.json", %{token: token, profile: profile}) do
    %{
      session_token: token
    }
    |> Map.merge(profile)
  end

  def render("invited_otp_respose.json", %{
        request_id: request_id,
        invites: invites,
        whitelisted: whitelisted,
        otp_requested_count: stored_otp_request_count,
        max_count_allowed: otp_request_limit
      }) do
    %{
      request_id: request_id,
      invites: render_many(invites, CredentialView, "invite.json", as: :invite),
      whitelisted: whitelisted,
      otp_requested_count: stored_otp_request_count,
      max_count_allowed: otp_request_limit
    }
  end

  def render("invite.json", %{invite: invite}) do
    profile_pic_url =
      if !is_nil(invite.profile_pic_url) &&
           !is_nil(invite.profile_pic_url["url"]),
         do: S3Helper.get_imgix_url(invite.profile_pic_url["url"])

    invite |> Map.merge(%{profile_pic_url: profile_pic_url})
  end

  def render("signup.json", %{token: token, profile: profile}) do
    %{
      session_token: token,
      show_billing_company_flow: true
    }
    |> Map.merge(profile)
  end

  def render("employees_data.json", %{data: data}) do
    data
    |> Enum.map(fn employee_data ->
      render("employee.json", %{employee: employee_data})
    end)
  end

  def render("new_employees_data.json", %{employees: employees}) do
    employee_data =
      employees
      |> Enum.map(fn employee ->
        render("employee.json", %{employee: employee})
      end)

    %{
      employees: employee_data
    }
  end

  def render("new_employees_data_with_metrics.json", %{employees: employees} = params) do
    employee_data =
      employees
      |> Enum.map(fn employee ->
        render("employee_with_metrics.json", %{employee: employee})
      end)

    %{
      has_next_page: params[:has_next_page],
      employees: employee_data
    }
  end

  def render("employee_with_metrics.json", %{employee: employee}) do
    metrics = EmployeeCredential.employee_performance_metrics(employee.id)
    employee = employee |> Repo.preload([:employee_role, :city, :reporting_manager])

    %{
      id: employee.id,
      uuid: employee.uuid,
      name: employee.name,
      inserted_at: employee.inserted_at,
      phone_number: employee.phone_number,
      last_active_at: employee.last_active_at,
      active: employee.active,
      profile_image_url: employee.profile_image_url,
      employee_role_id: employee.employee_role_id,
      hl_lead_allowed: employee.hl_lead_allowed,
      email: employee.email,
      employee_code: employee.employee_code,
      city_id: employee.city_id,
      city: if(not is_nil(employee.city), do: employee.city.name, else: nil),
      employee_role_name: employee.employee_role.name,
      reporting_manager:
        if(not is_nil(employee.reporting_manager),
          do: %{
            name: employee.reporting_manager.name,
            email: employee.reporting_manager.email,
            id: employee.reporting_manager.id
          },
          else: nil
        ),
      access_city_ids: employee.access_city_ids,
      vertical_id: employee.vertical_id
    }
    |> Map.merge(metrics)
  end

  def render("employee.json", %{employee: employee}) do
    employee = employee |> Repo.preload([:employee_role, :city, :reporting_manager])

    %{
      id: employee.id,
      uuid: employee.uuid,
      name: employee.name,
      phone_number: employee.phone_number,
      inserted_at: employee.inserted_at,
      last_active_at: employee.last_active_at,
      active: employee.active,
      email: employee.email,
      employee_code: employee.employee_code,
      profile_image_url: employee.profile_image_url,
      employee_role_id: employee.employee_role_id,
      hl_lead_allowed: employee.hl_lead_allowed,
      city_id: employee.city_id,
      city: if(not is_nil(employee.city), do: employee.city.name, else: nil),
      employee_role_name: employee.employee_role.name,
      reporting_manager:
        if(not is_nil(employee.reporting_manager),
          do: %{
            name: employee.reporting_manager.name,
            email: employee.reporting_manager.email,
            id: employee.reporting_manager.id
          },
          else: nil
        ),
      access_city_ids: employee.access_city_ids,
      vertical_id: employee.vertical_id
    }
  end

  def render("developer_poc.json", %{developer_poc: developer_poc}) do
    %{
      id: developer_poc.id,
      uuid: developer_poc.uuid,
      name: developer_poc.name,
      phone_number: developer_poc.phone_number,
      last_active_at: developer_poc.last_active_at,
      active: developer_poc.active
    }
  end

  def render("developer_pocs_data.json", %{data: data}) do
    data
    |> Enum.map(fn developer_poc_data ->
      render("developer_poc.json", %{developer_poc: developer_poc_data})
    end)
  end
end
