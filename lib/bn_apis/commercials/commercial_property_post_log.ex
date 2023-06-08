defmodule BnApis.Commercials.CommercialPropertyPostLog do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.CommercialPropertyPostLog
  alias BnApis.Helpers.Time

  schema "commercial_property_logs" do
    field :changes, :map
    field :user_id, :integer
    field :user_type, :string
    belongs_to(:commercial_property_post, CommercialPropertyPost)

    timestamps()
  end

  @fields [:changes, :user_id, :user_type, :commercial_property_post_id]
  @doc false
  def changeset(commercial_property_post_log, attrs) do
    commercial_property_post_log
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end

  def log(commercial_property_post_id, user_id, user_type, changeset) do
    params = %{
      "user_id" => user_id,
      "user_type" => user_type,
      "changes" => changeset.changes,
      "commercial_property_post_id" => commercial_property_post_id
    }

    %CommercialPropertyPostLog{}
    |> CommercialPropertyPostLog.changeset(params)
    |> Repo.insert!()
  end

  def get_latest_activation_date(post_id) do
    CommercialPropertyPostLog
    |> where([c], fragment("(changes ->> 'status') = 'ACTIVE'") and c.commercial_property_post_id == ^post_id)
    |> group_by([c], c.commercial_property_post_id)
    |> select([c], max(c.inserted_at))
    |> Repo.one()
    |> case do
      nil -> nil
      activation_date -> activation_date |> Time.naive_to_epoch_in_sec()
    end
  end
end
