defmodule BnApis.Accounts.DeveloperCredential do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.DeveloperCredential
  alias BnApis.Helpers.{S3Helper, ApplicationHelper, AuditedRepo}

  schema "developers_credentials" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :phone_number, :string
    field :name, :string
    field :profile_image_url, :string
    field :active, :boolean, default: false
    field :last_active_at, :naive_datetime

    timestamps()
  end

  @required_fields [:name, :phone_number]
  @fields @required_fields ++ [:profile_image_url, :active, :last_active_at]

  @doc false
  def changeset(developer_credential, attrs) do
    developer_credential
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  def all_developer_credentials do
    DeveloperCredential |> Repo.all()
  end

  def create_developer_credential(params, user_map) do
    params |> signup_user(user_map)
  end

  def get_id_from_uuid(uuid) do
    Repo.get_by(DeveloperCredential, uuid: uuid).id
  end

  @doc """
  1. Fetches active credential from phone number
  """
  def fetch_developer_credential(phone_number) do
    DeveloperCredential
    |> where([cred], cred.phone_number == ^phone_number and cred.active == true)
    |> Repo.one()
  end

  def upload_image_to_s3(profile_image, phone_number, extension \\ "") do
    case profile_image do
      nil ->
        {:ok, nil}

      %Plug.Upload{
        content_type: _content_type,
        filename: filename,
        path: filepath
      } ->
        working_directory = "tmp/file_worker/#{phone_number}"
        File.mkdir_p!(working_directory)

        image_filepath = "#{working_directory}/#{filename}"

        File.cp(filepath, image_filepath)

        file = File.read!(image_filepath)
        md5 = file |> :erlang.md5() |> Base.encode16(case: :lower)
        key = "#{phone_number}/#{md5}/#{filename}#{extension}"
        files_bucket = ApplicationHelper.get_files_bucket()
        {:ok, _message} = S3Helper.put_file(files_bucket, key, file)

        # removes file working directory before returning
        File.rm_rf(working_directory)
        {:ok, key}

      _ ->
        {:ok, nil}
    end
  end

  def signup_user(
        params = %{
          "name" => name,
          "phone_number" => phone_number
        },
        user_map
      ) do
    {:ok, uploaded_image_url} = upload_image_to_s3(params["profile_image"], phone_number)

    developer_credential_attrs = %{
      phone_number: phone_number,
      name: name,
      active: true,
      profile_image_url: uploaded_image_url
    }

    developer_credential_changeset = changeset(%DeveloperCredential{}, developer_credential_attrs)

    case developer_credential_changeset |> AuditedRepo.insert(user_map) do
      {:ok, developer_credential} ->
        {:ok, developer_credential}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_profile_pic_changeset(credential, params) do
    {:ok, uploaded_image_url} = upload_image_to_s3(params["profile_image"], credential.phone_number)
    credential |> changeset(%{"profile_image_url" => uploaded_image_url})
  end

  def update_profile_changeset(credential, _params = %{"name" => name}) do
    credential |> changeset(%{"name" => name})
  end

  def update_active_changeset(credential, status) do
    credential
    |> change(active: status)
  end

  def update_last_active_at_query(id) do
    __MODULE__
    |> where(id: ^id)
    |> Ecto.Query.update(set: [last_active_at: fragment("date_trunc('second',now() AT TIME ZONE 'UTC')")])
  end
end
