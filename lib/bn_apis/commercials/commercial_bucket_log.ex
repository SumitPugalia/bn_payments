defmodule BnApis.Commercials.CommercialBucketLog do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApis.Commercials.CommercialBucket
  alias BnApis.Helpers.Time
  alias BnApis.Commercials.CommercialBucketLog

  schema "commercial_bucket_logs" do
    field :opened_at, :integer
    field :active, :boolean, default: true

    belongs_to(:broker, Broker)
    belongs_to(:bucket, CommercialBucket)
    timestamps()
  end

  @required [:broker_id, :bucket_id]
  @optional [:opened_at, :active]
  def changeset(commercial_bucket_log, attrs) do
    commercial_bucket_log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:bucket_id)
  end

  def create(bucket_id, broker_id) do
    current_time = Timex.now() |> Time.naive_to_epoch_in_sec()

    ch =
      CommercialBucketLog.changeset(%CommercialBucketLog{}, %{
        "opened_at" => current_time,
        "broker_id" => broker_id,
        "bucket_id" => bucket_id
      })

    if ch.valid? do
      log = Repo.insert!(ch)
      {:ok, log.id}
    else
      {:error, ch}
    end
  end

  def update(bucket, params) do
    ch = bucket |> CommercialBucketLog.changeset(params)

    if ch.valid? do
      Repo.update(ch)
      {:ok, "updated successfully"}
    else
      {:error, ch}
    end
  end

  def get_log(bucket_id) do
    CommercialBucketLog
    |> where([l], l.bucket_id == ^bucket_id and l.active == ^true)
    |> order_by([l], desc: l.opened_at)
    |> select([l], %{
      opened_at: l.opened_at,
      active: l.active,
      broker_id: l.broker_id,
      bucket_id: l.bucket_id
    })
    |> Repo.all()
  end
end
