defmodule BnApis.Posts.ReportedRentalClientPost do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Posts.{RentalClientPost}
  alias BnApis.Accounts.Credential
  alias BnApis.Reasons.Reason
  alias BnApis.Posts.ReportedRentalClientPost

  schema "reported_rental_client_posts" do
    belongs_to :rental_client, RentalClientPost
    belongs_to :reported_by, Credential
    belongs_to :report_post_reason, Reason

    timestamps()
  end

  @fields [:rental_client_id, :reported_by_id, :report_post_reason_id]
  @required @fields

  @doc false
  def changeset(reported_rental_client_post, attrs) do
    reported_rental_client_post
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> unique_constraint(:reported_by_id, name: :a_re_reporting_not_allowed_index, message: "Post already reported!")
  end

  def report_post(
        params = %{
          post_id: post_id,
          reported_by_id: _user_id,
          report_post_reason_id: _reason_id
        }
      ) do
    params = params |> Map.merge(%{rental_client_id: post_id})

    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert()
  end

  def get_reported_rental_client_post_ids(logged_user_id) do
    Repo.all(
      from rrcp in ReportedRentalClientPost,
        where: rrcp.reported_by_id == ^logged_user_id,
        select: rrcp.rental_client_id
    )
  end
end
