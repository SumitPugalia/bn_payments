defmodule BnApis.Accounts.DeveloperPocCredential do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Stories.StoryDeveloperPocMapping
  alias BnApis.Helpers.{S3Helper, AuditedRepo}

  schema "developer_poc_credentials" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:phone_number, :string)
    field :country_code, :string, default: "+91"
    field(:name, :string)
    field(:active, :boolean, default: false)
    field(:last_active_at, :naive_datetime)
    field(:profile_pic_url, :string)
    field(:fcm_id, :string)
    field(:platform, :string)

    has_many(:story_developer_poc_mappings, StoryDeveloperPocMapping)
    timestamps()
  end

  @required_fields [:name, :phone_number]
  @fields @required_fields ++ [:active, :last_active_at, :profile_pic_url, :country_code, :fcm_id, :platform]

  @doc false
  def changeset(developer_poc_credential, attrs) do
    developer_poc_credential
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:phone_number)
  end

  def signup_user(
        %{
          "name" => name,
          "phone_number" => phone_number,
          "country_code" => country_code
        },
        user_map
      ) do
    poc_credential_attrs = %{
      phone_number: phone_number,
      country_code: country_code,
      name: name,
      active: true
    }

    poc_credential_changeset = changeset(%DeveloperPocCredential{}, poc_credential_attrs)

    AuditedRepo.insert(poc_credential_changeset, user_map)
  end

  def update(developer_poc_credential, attrs, user_map) do
    params = attrs |> Map.take(["name", "phone_number", "active", "country_code"])
    changeset = changeset(developer_poc_credential, params)
    AuditedRepo.update(changeset, user_map)
  end

  def all_developer_pocs() do
    Repo.all(DeveloperPocCredential)
  end

  def search_developer_pocs(%{"q" => q}) when is_binary(q) and q != "" do
    limit = 30
    name_query = "%#{String.downcase(q)}%"

    developer_pocs =
      DeveloperPocCredential
      |> where([l], l.phone_number == ^q or fragment("LOWER(?) LIKE ?", l.name, ^name_query))
      |> where([l], l.active == true)
      |> limit(^limit)
      |> Repo.all()
      |> get_developer_poc_details_for_panel()

    %{
      developer_pocs: developer_pocs
    }
  end

  def search_developer_pocs(_params) do
    %{
      developer_pocs: []
    }
  end

  defp get_developer_poc_details_for_panel(developer_pocs) when is_list(developer_pocs) do
    developer_pocs |> Enum.map(&get_developer_poc_details_for_panel(&1))
  end

  defp get_developer_poc_details_for_panel(developer_poc) do
    %{
      id: developer_poc.id,
      uuid: developer_poc.uuid,
      name: developer_poc.name,
      phone_number: developer_poc.phone_number,
      country_code: developer_poc.country_code,
      profile_pic_url: get_profile_image_url(developer_poc)
    }
  end

  def update_last_active_at_query(id) do
    __MODULE__
    |> where(id: ^id)
    |> Ecto.Query.update(
      set: [
        last_active_at: fragment("date_trunc('second',now() AT TIME ZONE 'UTC')")
      ]
    )
  end

  def to_map(nil), do: %{}
  def to_map(developer_pocs) when is_list(developer_pocs), do: developer_pocs |> Enum.map(&to_map(&1))

  def to_map(developer_poc) do
    %{
      uuid: developer_poc.uuid,
      name: developer_poc.name,
      phone_number: developer_poc.phone_number,
      country_code: developer_poc.country_code,
      profile_pic_url: get_profile_image_url(developer_poc)
    }
  end

  defp get_profile_image_url(developer_poc) do
    case developer_poc.profile_pic_url do
      nil -> nil
      %{"url" => nil} -> nil
      %{"url" => url} -> S3Helper.get_imgix_url(url)
    end
  end

  def fetch_developer_poc_credential(phone_number, country_code) do
    DeveloperPocCredential
    |> where([cred], cred.phone_number == ^phone_number and cred.country_code == ^country_code)
    |> Repo.one()
  end

  def fetch_developer_poc_credential_by_id(id) do
    DeveloperPocCredential
    |> Repo.get(id)
  end

  def fetch_developer_poc_associated_to_story(phone_number, country_code) do
    developer_poc =
      DeveloperPocCredential
      |> where([cred], cred.phone_number == ^phone_number and cred.country_code == ^country_code)
      |> Repo.one()

    if not is_nil(developer_poc) do
      mapping =
        StoryDeveloperPocMapping
        |> where([record], record.developer_poc_credential_id == ^developer_poc.id)
        |> where([record], record.active == true)
        |> Repo.all()
        |> List.last()

      case mapping do
        nil ->
          {:error, "Developer POC not associated to any story."}

        _ ->
          {:ok, mapping}
      end
    else
      {:error, "Developer POC account not found."}
    end
  end

  def fetch_bn_approver_credential() do
    fetch_developer_poc_credential("9000000000", "+91")
  end
end
