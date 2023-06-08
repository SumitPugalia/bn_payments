defmodule BnApis.Stories.StorySalesKit do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Stories.{Story, AttachmentType}
  alias BnApis.Helpers.ApplicationHelper

  schema "stories_sales_kits" do
    field :name, :string
    field :preview_url, :string
    field :share_url, :string
    field :size_in_mb, :decimal
    field :thumbnail, :string
    field :youtube_url, :string
    field :active, :boolean, default: true
    field :uuid, Ecto.UUID, read_after_writes: true

    belongs_to :attachment_type, AttachmentType
    belongs_to :story, Story
    timestamps()
  end

  @fields [
    :name,
    :thumbnail,
    :share_url,
    :preview_url,
    :size_in_mb,
    :attachment_type_id,
    :story_id,
    :active,
    :youtube_url
  ]
  @required_fields [:name, :attachment_type_id]

  @doc false
  def changeset(story_sales_kit, attrs \\ %{}) do
    story_sales_kit
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_attachment_type_for_youtube_url()
    |> validate_youtube_url()
    |> validate_change(:youtube_url, &validate_youtube_url_format/2)
    |> foreign_key_constraint(:story_id)
  end

  def fetch_s3_path(story_sales_kit) do
    imgix_domain = ApplicationHelper.get_imgix_domain()

    imgix_domain =
      if !String.contains?(story_sales_kit.share_url, imgix_domain) do
        ApplicationHelper.get_imgix_domain()
      else
        imgix_domain
      end

    story_sales_kit.share_url
    |> String.replace("%20", " ")
    |> String.replace(imgix_domain, "")
  end

  ## Private APIs

  defp validate_attachment_type_for_youtube_url(changeset) do
    case changeset.valid? do
      true ->
        attachment_type_id = get_field(changeset, :attachment_type_id)

        if attachment_type_id == AttachmentType.youtube_url().id do
          validate_required(changeset, [:youtube_url])
        else
          changeset
        end

      false ->
        changeset
    end
  end

  defp validate_youtube_url(changeset) do
    case changeset.valid? do
      true ->
        attachment_type_id = get_field(changeset, :attachment_type_id)
        youtube_url = get_field(changeset, :youtube_url)

        is_youtube_url_nil? = is_nil(youtube_url)
        is_valid_attachment_type_id? = attachment_type_id == AttachmentType.youtube_url().id

        case {is_youtube_url_nil?, is_valid_attachment_type_id?} do
          {true, _} ->
            changeset

          {false, true} ->
            changeset

          {false, false} ->
            add_error(changeset, :youtube_url, "Select You tube URL as attachment type.")
        end

      false ->
        changeset
    end
  end

  def validate_youtube_url_format(:youtube_url, youtube_url) do
    youtube_url_regex = ~r/^(?:https?:\/\/)?(?:m\.|www\.)?(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|shorts\/|watch\?v=|watch\?.+&v=))((\w|-){11})(?:\S+)?$/

    is_valid_youtube_url? = String.match?(youtube_url, youtube_url_regex)

    case is_valid_youtube_url? do
      true ->
        []

      false ->
        [youtube_url: "Invalid youtube url."]
    end
  end
end
