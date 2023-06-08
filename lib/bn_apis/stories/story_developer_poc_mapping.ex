defmodule BnApis.Stories.StoryDeveloperPocMapping do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  alias BnApis.Stories.Story
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Stories.StoryDeveloperPocMapping
  alias BnApis.Repo

  schema "story_developer_poc_mappings" do
    belongs_to(:story, Story)
    belongs_to(:developer_poc_credential, DeveloperPocCredential)

    field(:user_id, :integer)
    field(:user_type, :string)
    field(:active, :boolean, default: false)

    timestamps()
  end

  @required_fields [:story_id, :developer_poc_credential_id, :active]
  @fields @required_fields ++ [:user_id, :user_type]

  @doc false
  def changeset(story_developer_poc_mapping, attrs) do
    story_developer_poc_mapping
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:story_id, name: :uniq_story_poc_mapping_index)
  end

  def activate_story_developer_poc_mapping!(
        story_id,
        developer_poc_credential_id,
        user_id,
        user_type
      ) do
    case fetch(story_id, developer_poc_credential_id) do
      nil ->
        attrs = %{
          story_id: story_id,
          developer_poc_credential_id: developer_poc_credential_id,
          active: true,
          user_id: user_id,
          user_type: user_type
        }

        create!(attrs)

      story_developer_poc_mapping ->
        update!(story_developer_poc_mapping, %{active: true, user_id: user_id, user_type: user_type})
    end
  end

  def deactivate_story_developer_poc_mapping!(
        story_id,
        developer_poc_credential_id,
        user_id,
        user_type
      ) do
    case fetch(story_id, developer_poc_credential_id) do
      nil ->
        {:ok, nil}

      story_developer_poc_mapping ->
        update!(story_developer_poc_mapping, %{active: false, user_id: user_id, user_type: user_type})
    end
  end

  def get_story_map_from_poc_credential_id(poc_credential_id) do
    StoryDeveloperPocMapping
    |> where([m], m.developer_poc_credential_id == ^poc_credential_id and m.active == true)
    |> preload([:story])
    |> order_by([m], desc: m.updated_at)
    |> Repo.all()
    |> List.last()
  end

  def get_any_poc_details_from_story_id(story_id) do
    get_all_poc_mappings_from_story_id(story_id)
    |> Enum.map(fn mp -> mp.developer_poc_credential end)
    |> List.first()
  end

  def get_active_poc_details_from_story_id(story_id) do
    get_all_poc_mappings_from_story_id(story_id)
    |> Enum.filter(fn mp -> mp.active end)
    |> Enum.map(fn mp -> mp.developer_poc_credential end)
    |> List.first()
  end

  def get_all_poc_mappings_from_story_id(story_id) do
    StoryDeveloperPocMapping
    |> where([m], m.story_id == ^story_id)
    |> preload([:developer_poc_credential])
    |> order_by([m], desc: m.active, desc: m.updated_at)
    |> Repo.all()
  end

  # Private methods

  defp create!(attrs) do
    StoryDeveloperPocMapping.changeset(%StoryDeveloperPocMapping{}, attrs)
    |> Repo.insert!()
  end

  defp update!(story_developer_poc_mapping, attrs) do
    StoryDeveloperPocMapping.changeset(story_developer_poc_mapping, attrs)
    |> Repo.update!()
  end

  defp fetch(story_id, developer_poc_credential_id) do
    Repo.one(
      from(d in StoryDeveloperPocMapping,
        where:
          d.story_id == ^story_id and
            d.developer_poc_credential_id == ^developer_poc_credential_id
      )
    )
  end
end
