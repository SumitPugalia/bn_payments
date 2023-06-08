defmodule BnApis.Reasons.ReasonType do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Reasons.Reason

  @delete_post_client %{id: 1, name: "Delete Post Client", key: "delete_post_client", reason_key: "delete_post_client"}
  @block_broker %{id: 2, name: "Block Broker", key: "block_broker", reason_key: "block_broker"}
  @delete_post_property %{
    id: 3,
    name: "Delete Post Property",
    key: "delete_post_property",
    reason_key: "delete_post_property"
  }
  @report_post %{id: 4, name: "Report Post", key: "report_post", reason_key: "report_post"}
  @report_owner_post %{id: 5, name: "Report Owner Post", key: "report_owner_post", reason_key: "report_owner_post"}

  @report_commercial_post %{
    id: 6,
    name: "Report Commercial Post",
    key: "report_commercial_post",
    reason_key: "report_commercial_post"
  }
  @report_commercial_site_visit %{
    id: 7,
    name: "Report Commercial Site Visit",
    key: "report_commercial_site_visit",
    reason_key: "report_commercial_site_visit"
  }

  @delete_bucket %{id: 8, name: "Delete Bucket", key: "delete_bucket", reason_key: "delete_bucket"}
  @refresh_post_property %{
    id: 9,
    name: "Refresh Post Property",
    key: "refresh_post_property",
    reason_key: "refresh_post_property"
  }

  # @primary_key false
  schema "reasons_types" do
    # field :id, :integer, primary_key: true
    field :name, :string
    field :reason_key, :string
    has_many :reasons, Reason, foreign_key: :reason_type_id

    timestamps()
  end

  def seed_data do
    [
      @delete_post_client,
      @delete_post_property,
      @block_broker,
      @report_post,
      @report_owner_post,
      @report_commercial_post,
      @report_commercial_site_visit,
      @delete_bucket,
      @refresh_post_property
    ]
  end

  def changeset(status, params) do
    status
    |> cast(params, [:id, :name, :reason_key])
    |> validate_required([:id, :name, :reason_key])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def delete_post_client do
    @delete_post_client
  end

  def delete_post_property do
    @delete_post_property
  end

  def block_broker do
    @block_broker
  end

  def report_post do
    @report_post
  end

  def report_owner_post do
    @report_owner_post
  end

  def report_commercial_post do
    @report_commercial_post
  end

  def report_commercial_site_visit do
    @report_commercial_site_visit
  end

  def delete_bucket do
    @delete_bucket
  end

  def refresh_post_property do
    @refresh_post_property
  end

  def get_by_id(id) do
    seed_data()
    |> Enum.filter(&(&1.id == id))
    |> List.first()
  end

  def get_by_name(name) do
    seed_data()
    |> Enum.filter(&(&1.name == name))
    |> List.first()
  end
end
