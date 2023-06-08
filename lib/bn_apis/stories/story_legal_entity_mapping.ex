defmodule BnApis.Stories.StoryLegalEntityMapping do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Stories.Story
  alias BnApis.Stories.LegalEntity
  alias BnApis.Stories.StoryLegalEntityMapping

  schema "story_legal_entity_mappings" do
    belongs_to(:story, Story)
    belongs_to(:legal_entity, LegalEntity)

    field(:active, :boolean, default: false)

    timestamps()
  end

  @required_fields [:story_id, :legal_entity_id, :active]
  @fields @required_fields ++ []

  @doc false
  def changeset(story_legal_entity_mapping, attrs) do
    story_legal_entity_mapping
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:legal_entity_id)
    |> foreign_key_constraint(:story_id)
    |> unique_constraint(:legal_entity_id,
      name: :unique_stories_legal_entity_mapping_index,
      message: "The story_id to legal_entity_id mapping already exixts."
    )
  end

  def get_stories_for_legal_entity(legal_entity_id) do
    StoryLegalEntityMapping
    |> where([m], m.legal_entity_id == ^legal_entity_id and m.active == true)
    |> preload([:story])
    |> Repo.all()
    |> Enum.map(fn story -> %{story_uuid: story.story.uuid, story_name: story.story.name} end)
  end

  def get_legal_entities_for_story(story_id) do
    StoryLegalEntityMapping
    |> where([m], m.story_id == ^story_id and m.active == true)
    |> preload([:legal_entity, :story])
    |> Repo.all()
    |> Enum.map(fn le ->
      %{
        billing_address: le.legal_entity.billing_address,
        gst: le.legal_entity.gst,
        inserted_at: le.legal_entity.inserted_at,
        legal_entity_name: le.legal_entity.legal_entity_name,
        pan: le.legal_entity.pan,
        place_of_supply: le.legal_entity.place_of_supply,
        sac: le.legal_entity.sac,
        state_code: le.legal_entity.state_code,
        updated_at: le.legal_entity.updated_at,
        uuid: le.legal_entity.uuid,
        id: le.legal_entity.id,
        rera_ids: le.story.rera_ids,
        shipping_address: le.legal_entity.shipping_address,
        ship_to_name: le.legal_entity.ship_to_name
      }
    end)
  end

  def get_active_legal_entities_for_story(story_id) do
    StoryLegalEntityMapping
    |> where([m], m.story_id == ^story_id and m.active == true)
    |> select([m], m.legal_entity_id)
    |> Repo.all()
  end

  def activate_story_legal_entity_mapping(story_id, legal_entity_id) do
    case fetch(story_id, legal_entity_id) do
      nil ->
        attrs = %{
          story_id: story_id,
          legal_entity_id: legal_entity_id,
          active: true
        }

        create!(attrs)

      story_legal_entity_mapping ->
        update!(story_legal_entity_mapping, %{active: true})
    end
  end

  def deactivate_story_legal_entity_mapping(story_id, legal_entity_id) do
    case fetch(story_id, legal_entity_id) do
      nil ->
        {:ok, nil}

      story_legal_entity_mapping ->
        update!(story_legal_entity_mapping, %{active: false})
    end
  end

  # Private methods

  defp create!(attrs) do
    StoryLegalEntityMapping.changeset(%StoryLegalEntityMapping{}, attrs)
    |> Repo.insert!()
  end

  defp update!(story_legal_entity_mapping, attrs) do
    StoryLegalEntityMapping.changeset(story_legal_entity_mapping, attrs)
    |> Repo.update!()
  end

  defp fetch(story_id, legal_entity_id) do
    Repo.one(
      from(mapping in StoryLegalEntityMapping,
        where:
          mapping.story_id == ^story_id and
            mapping.legal_entity_id == ^legal_entity_id and
            mapping.active == true
      )
    )
  end
end
