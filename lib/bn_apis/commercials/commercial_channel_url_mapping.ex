defmodule BnApis.Commercials.CommercialChannelUrlMapping do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.CommercialChannelUrlMapping

  schema "commercial_channel_url_mapping" do
    field :is_active, :boolean, default: true
    field :channel_url, :string
    field :user_ids, {:array, :integer}, default: []

    belongs_to(:broker, Broker)
    belongs_to(:commercial_property_post, CommercialPropertyPost)
    timestamps()
  end

  @required [:is_active, :channel_url, :broker_id, :commercial_property_post_id]
  @optional [:user_ids]

  def changeset(commercial_channel_url_mapping, attrs) do
    commercial_channel_url_mapping
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end

  def get_commercial_url(post_id, broker_id) do
    channel_url_mapping =
      CommercialChannelUrlMapping
      |> where(
        [ccum],
        ccum.broker_id == ^broker_id and ccum.commercial_property_post_id == ^post_id and ccum.is_active == true and
          not is_nil(ccum.channel_url)
      )
      |> Repo.all()
      |> List.last()

    case channel_url_mapping do
      nil ->
        nil

      channel_url_mapping ->
        channel_url_mapping.channel_url
    end
  end

  def get_channel_details(channel_url) do
    commercial_channel_url_mapping = Repo.get_by(CommercialChannelUrlMapping, channel_url: channel_url)

    case commercial_channel_url_mapping do
      nil ->
        {:error, %{}}

      commercial_channel_url_mapping ->
        commercial_channel_url_mapping = commercial_channel_url_mapping |> Repo.preload(:broker)
        credential = Credential.get_credential_from_broker_id(commercial_channel_url_mapping.broker_id)

        {:ok,
         %{
           broker_name: commercial_channel_url_mapping.broker.name,
           broker_phone: "#{credential.country_code}#{credential.phone_number}",
           post_id: commercial_channel_url_mapping.commercial_property_post_id
         }}
    end
  end

  def update(commercial_chat_mapping, params) do
    commercial_chat_mapping
    |> CommercialChannelUrlMapping.changeset(params)
    |> Repo.update()
  end

  def insert(params) do
    %CommercialChannelUrlMapping{}
    |> CommercialChannelUrlMapping.changeset(params)
    |> Repo.insert()
  end
end
