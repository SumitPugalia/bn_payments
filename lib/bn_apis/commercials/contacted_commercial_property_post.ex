defmodule BnApis.Commercials.ContactedCommercialPropertyPost do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Helpers.Time
  alias BnApis.Accounts.Credential
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.ContactedCommercialPropertyPost

  schema "contacted_commercial_property_posts" do
    belongs_to :commercial_property_post, CommercialPropertyPost
    belongs_to :contacted_by, Credential
    field :call_time, :integer

    timestamps()
  end

  @required [:commercial_property_post_id, :contacted_by_id, :call_time]

  @doc false
  def changeset(commercial_property_post, attrs) do
    commercial_property_post
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> foreign_key_constraint(:commercial_property_post_id)
    |> foreign_key_constraint(:contacted_by_id)
  end

  def add_contacted_details(post_uuid, user_id) do
    case CommercialPropertyPost.fetch_post_by_uuid(post_uuid) do
      nil ->
        {:error, "Post not found"}

      post ->
        changes = %{
          "commercial_property_post_id" => post.id,
          "contacted_by_id" => user_id,
          "call_time" => NaiveDateTime.utc_now() |> Time.naive_to_epoch_in_sec()
        }

        %ContactedCommercialPropertyPost{}
        |> changeset(changes)
        |> Repo.insert()
    end
  end

  def get_latest_contacted_details_for_post_by_broker_id(logged_in_user_id, post_id) do
    ContactedCommercialPropertyPost
    |> where([ccp], ccp.contacted_by_id == ^logged_in_user_id)
    |> where([ccp], ccp.commercial_property_post_id == ^post_id)
    |> order_by([ccp], desc: ccp.inserted_at)
    |> select([ccp], %{
      id: ccp.id,
      commercial_property_post_id: ccp.commercial_property_post_id,
      contacted_by_id: ccp.contacted_by_id,
      call_time: ccp.call_time
    })
    |> Repo.all()
    |> List.first()
  end
end
