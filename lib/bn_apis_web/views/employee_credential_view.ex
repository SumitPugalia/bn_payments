defmodule BnApisWeb.EmployeeCredentialView do
  use BnApisWeb, :view
  alias BnApisWeb.EmployeeCredentialView

  def render("index.json", %{employees_credentials: employees_credentials}) do
    %{data: render_many(employees_credentials, EmployeeCredentialView, "employee_credential.json")}
  end

  def render("show.json", %{employee_credential: employee_credential}) do
    %{data: render_one(employee_credential, EmployeeCredentialView, "employee_credential.json")}
  end

  def render("employee_credential.json", %{employee_credential: employee_credential}) do
    %{
      id: employee_credential.id,
      uuid: employee_credential.uuid,
      name: employee_credential.name,
      profile_image_url: employee_credential.profile_image_url,
      phone_number: employee_credential.phone_number,
      active: employee_credential.active,
      last_active_at: employee_credential.last_active_at
    }
  end
end
