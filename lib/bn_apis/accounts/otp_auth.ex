defmodule BnApis.Accounts.OtpAuth do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Accounts.{OtpAuth, Credential}
  alias Ecto.Multi
  alias BnApis.Repo

  embedded_schema do
    field :phone_number, :string
  end

  @doc false
  def changeset(%OtpAuth{} = otp_auth, attrs) do
    otp_auth
    |> cast(attrs, [:phone_number])
    |> validate_required([:phone_number])
  end

  @doc """
    saves using embedded_schema(for clear intent)
  """
  def save_phone_number(params) do
    chset = changeset(%OtpAuth{}, params)

    Multi.new()
    |> Multi.run(:otp_auth, &apply_phone_number(&1, chset))
    |> Multi.run(:user, fn ops ->
      Repo.insert(to_credential_changeset(%Credential{}, ops.otp_auth))
    end)
    |> Repo.transaction()
  end

  defp apply_phone_number(_changes, changeset) do
    if changeset.valid? do
      {:ok, apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  defp to_credential_changeset(credential, %OtpAuth{} = otp_auth) do
    cast(credential, Map.take(otp_auth, [:phone_number]), [:phone_number])
  end
end
