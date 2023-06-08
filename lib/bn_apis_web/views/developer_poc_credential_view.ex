defmodule BnApisWeb.DeveloperPocCredentialView do
  use BnApisWeb, :view

  def render("verify_otp.json", %{token: token, profile: profile}) do
    %{
      session_token: token
    }
    |> Map.merge(profile)
  end

  def render("signup.json", %{token: token, profile: profile}) do
    %{
      session_token: token
    }
    |> Map.merge(profile)
  end
end
