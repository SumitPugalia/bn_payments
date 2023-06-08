defmodule BnApis.Posts.ContactedResalePropertyPost do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Posts.ResalePropertyPost
  alias BnApis.Organizations.Broker
  alias BnApis.Posts.ContactedResalePropertyPost

  schema "contacted_resale_property_posts" do
    belongs_to :post, ResalePropertyPost
    belongs_to :user, Broker
    field :count, :integer

    timestamps()
  end

  @required [:post_id, :user_id, :count]

  @doc false
  def changeset(contacted_resale_property_post, attrs) do
    contacted_resale_property_post
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:user_id)
  end

  def mark_contacted(post_id, user_id, is_contact_successful) do
    contacted_post = ContactedResalePropertyPost |> where([crp], crp.post_id == ^post_id and crp.user_id == ^user_id) |> Repo.one()
    initial_contact_count = if is_contact_successful, do: 1, else: 0

    contacted_post =
      cond do
        not is_nil(contacted_post) and not is_contact_successful ->
          contacted_post

        not is_nil(contacted_post) and is_contact_successful ->
          contacted_post
          |> ContactedResalePropertyPost.changeset(%{"count" => contacted_post.count + 1})
          |> Repo.update!()

        is_nil(contacted_post) ->
          %ContactedResalePropertyPost{}
          |> ContactedResalePropertyPost.changeset(%{"count" => initial_contact_count, "post_id" => post_id, "user_id" => user_id})
          |> Repo.insert!()
      end

    %{
      id: contacted_post.id,
      count: contacted_post.count,
      contacted_at: contacted_post.updated_at
    }
  end
end
