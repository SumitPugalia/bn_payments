defmodule BnApis.Rewards.StoryTierPlanMapping do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias BnApis.Repo
  alias BnApis.Rewards.Story
  alias BnApis.Rewards.StoryTier
  alias BnApis.Rewards.StoryTierPlanMapping

  schema "story_tier_plan_mapping" do
    field(:start_date, :naive_datetime)
    field(:end_date, :naive_datetime)
    field(:active, :boolean, default: true)

    belongs_to(:story, Story)

    belongs_to(:story_tier, StoryTier)

    timestamps()
  end

  @required [:start_date, :end_date, :story_id, :story_tier_id, :active]
  @optional []

  @doc false
  def changeset(story_tier_plan_mapping, attrs, id \\ nil) do
    story_tier_plan_mapping
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_end_date_gt_start_date()
    |> validate_non_overlapping_dates(id)
    |> foreign_key_constraint(:story_tier_id)
    |> foreign_key_constraint(:story_id)
  end

  def create_story_tier_mapping(params) do
    {story_id, story_tier_id} = {params["story_id"], params["story_tier_id"]}
    {start_date, end_date} = {params["start_date"], params["end_date"]}

    story_id = if is_binary(story_id), do: String.to_integer(story_id), else: story_id
    story_tier_id = if is_binary(story_tier_id), do: String.to_integer(story_tier_id), else: story_tier_id

    start_date = if is_binary(start_date), do: String.to_integer(start_date), else: start_date
    start_date = if !is_nil(start_date), do: DateTime.from_unix!(start_date) |> DateTime.to_naive()

    end_date = if is_binary(end_date), do: String.to_integer(end_date), else: end_date
    end_date = DateTime.from_unix!(end_date) |> DateTime.to_naive()

    changeset =
      StoryTierPlanMapping.changeset(%StoryTierPlanMapping{}, %{
        start_date: start_date,
        end_date: end_date,
        story_id: story_id,
        story_tier_id: story_tier_id,
        active: true
      })

    Repo.insert(changeset)
  end

  def get_story_tier_plans(story_id) do
    StoryTierPlanMapping
    |> where([sm], sm.story_id == ^story_id and sm.active == ^true)
    |> Repo.all()
    |> Enum.map(fn sm ->
      %{
        story_tier_plan_mapping_id: sm.id,
        story_id: sm.story_id,
        story_tier_id: sm.story_tier_id,
        start_date: sm.start_date |> Timex.to_datetime() |> DateTime.to_unix(),
        end_date: sm.end_date |> Timex.to_datetime() |> DateTime.to_unix(),
        active: sm.active
      }
    end)
    |> Enum.sort_by(& &1.start_date)
  end

  def update_story_tier_plan(params) do
    {start_date, end_date} = {params["start_date"], params["end_date"]}
    story_tier_plan_mapping_id = params["story_tier_plan_mapping_id"]
    story_tier_id = params["story_tier_id"]

    story_tier_id = if !is_nil(story_tier_id) and is_binary(story_tier_id), do: String.to_integer(story_tier_id), else: story_tier_id

    story_tier_plan_mapping_id =
      if !is_nil(story_tier_plan_mapping_id) and is_binary(story_tier_plan_mapping_id) do
        String.to_integer(story_tier_plan_mapping_id)
      else
        story_tier_plan_mapping_id
      end

    start_date = if !is_nil(start_date) and is_binary(start_date), do: String.to_integer(start_date), else: start_date
    start_date = if !is_nil(start_date), do: DateTime.from_unix!(start_date) |> DateTime.to_naive()

    end_date = if !is_nil(end_date) and is_binary(end_date), do: String.to_integer(end_date), else: end_date
    end_date = if !is_nil(end_date), do: DateTime.from_unix!(end_date) |> DateTime.to_naive()

    update_operation =
      if params["delete"] do
        %{active: false}
      else
        %{start_date: start_date, end_date: end_date, story_tier_id: story_tier_id}
      end

    case Repo.get_by(StoryTierPlanMapping, id: story_tier_plan_mapping_id, active: true) do
      nil ->
        {:error, "Mapping does not even exist!"}

      mapping ->
        mapping
        |> changeset(update_operation, story_tier_plan_mapping_id)
        |> Repo.update()
    end
  end

  defp validate_end_date_gt_start_date(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    case changeset.changes[:start_date] do
      nil ->
        changeset

      _ ->
        cond do
          is_greater_than_equal_to(end_date, start_date) ->
            changeset

          true ->
            changeset |> add_error(start_date, "Start date can't be greater than end date")
        end
    end
  end

  defp validate_non_overlapping_dates(changeset, mapping_id) do
    story_id = get_field(changeset, :story_id)
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    case changeset.changes[:start_date] do
      nil ->
        changeset

      _ ->
        error_flag = compare_existing_dates_and_return_flag(start_date, end_date, story_id, mapping_id)

        cond do
          error_flag == "start_date_error" ->
            changeset |> add_error(start_date, "Start date overlapping with the existing dates")

          error_flag == "end_date_error" ->
            changeset |> add_error(end_date, "End date overlapping with the existing dates")

          true ->
            changeset
        end
    end
  end

  defp compare_existing_dates_and_return_flag(start_date, end_date, story_id, mapping_id) do
    StoryTierPlanMapping.get_story_tier_plans(story_id)
    |> Enum.reduce("no_error", fn item, acc ->
      # execute only until no error found and if we are not updating the same mapping_id
      if (acc == "no_error" || is_nil(acc)) and item.story_tier_plan_mapping_id != mapping_id do
        # convert epoch to NaiveDatetime
        item_start_date = item.start_date |> DateTime.from_unix!() |> DateTime.to_naive()
        item_end_date = item.end_date |> DateTime.from_unix!() |> DateTime.to_naive()

        cond do
          is_greater_than_equal_to(start_date, item_start_date) and is_less_than_equal_to(start_date, item_end_date) ->
            "start_date_error"

          is_greater_than_equal_to(end_date, item_start_date) and is_less_than_equal_to(end_date, item_end_date) ->
            "end_date_error"

          true ->
            nil
        end
      else
        acc
      end
    end)
  end

  defp is_greater_than_equal_to(date1, date2) do
    case NaiveDateTime.compare(date1, date2) do
      :eq -> true
      :gt -> true
      _ -> false
    end
  end

  defp is_less_than_equal_to(date1, date2) do
    case NaiveDateTime.compare(date1, date2) do
      :eq -> true
      :lt -> true
      _ -> false
    end
  end
end
