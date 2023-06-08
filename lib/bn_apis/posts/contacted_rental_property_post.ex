defmodule BnApis.Posts.ContactedRentalPropertyPost do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Posts.RentalPropertyPost
  alias BnApis.Organizations.Broker
  alias BnApis.Posts.ContactedRentalPropertyPost

  schema "contacted_rental_property_posts" do
    belongs_to :post, RentalPropertyPost
    belongs_to :user, Broker
    field :count, :integer

    timestamps()
  end

  @required [:post_id, :user_id, :count]

  @doc false
  def changeset(contacted_rental_property_post, attrs) do
    contacted_rental_property_post
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:user_id)
  end

  def mark_contacted(post_id, user_id, is_contact_successful) do
    contacted_post = ContactedRentalPropertyPost |> where([crp], crp.post_id == ^post_id and crp.user_id == ^user_id) |> Repo.one()
    initial_contact_count = if is_contact_successful, do: 1, else: 0

    contacted_post =
      cond do
        not is_nil(contacted_post) and not is_contact_successful ->
          contacted_post

        not is_nil(contacted_post) and is_contact_successful ->
          contacted_post
          |> ContactedRentalPropertyPost.changeset(%{"count" => contacted_post.count + 1})
          |> Repo.update!()

        is_nil(contacted_post) ->
          %ContactedRentalPropertyPost{}
          |> ContactedRentalPropertyPost.changeset(%{"count" => initial_contact_count, "post_id" => post_id, "user_id" => user_id})
          |> Repo.insert!()
      end

    %{
      id: contacted_post.id,
      count: contacted_post.count,
      contacted_at: contacted_post.updated_at
    }
  end
end
