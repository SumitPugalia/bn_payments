defmodule BnApis.Posts.ContactedPosts do
  use Ecto.Schema
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Posts
  alias BnApis.Posts.{ContactedRentalPropertyPost, ContactedResalePropertyPost}
  alias BnApis.Helpers.Time

  @restriction_limit_for_post_contact_per_day Posts.restriction_limit_for_post_contact_per_day()
  @warning_limit_for_post_contact_per_day Posts.warning_limit_for_post_contact_per_day()
  @restriction_limit_for_unverified_property_per_day_by_owner Posts.restriction_limit_for_unverified_property_per_day_by_owner()

  def get_contacted_info_by_user_id(broker_id, post_uuid, post_type) do
    start_time_unix = Time.get_start_time_in_unix(0)
    end_time_unix = Time.get_end_time_in_unix(0)

    successful_rental_contacted_post_count =
      ContactedRentalPropertyPost
      |> where([crp], crp.user_id == ^broker_id and crp.count > 0)
      |> where(
        [crp],
        ^start_time_unix <= fragment("ROUND(extract(epoch from ?))", crp.inserted_at) and
          ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", crp.inserted_at)
      )
      |> Repo.aggregate(:count, :id)

    successful_resale_contacted_post_count =
      ContactedResalePropertyPost
      |> where([crp], crp.user_id == ^broker_id and crp.count > 0)
      |> where(
        [crp],
        ^start_time_unix <= fragment("ROUND(extract(epoch from ?))", crp.inserted_at) and
          ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", crp.inserted_at)
      )
      |> Repo.aggregate(:count, :id)

    post_map = Posts.post_map(post_type)

    post = Repo.get_by(post_map.module, uuid: post_uuid)

    total_post_contacted_successfully = successful_rental_contacted_post_count + successful_resale_contacted_post_count
    is_contacted_in_past = is_post_contacted_in_past(broker_id, post.id, post_type)

    number_of_brokers_contacted = fetch_number_of_brokers_contacted(post_map.contacted_module, post.id, start_time_unix, end_time_unix)
    is_post_restricted_by_owner = check_if_restricted_by_owner(post.is_verified, number_of_brokers_contacted, is_contacted_in_past)
    to_be_restricted = (total_post_contacted_successfully > @restriction_limit_for_post_contact_per_day and not is_contacted_in_past) or is_post_restricted_by_owner
    to_be_warned = not to_be_restricted and total_post_contacted_successfully >= @warning_limit_for_post_contact_per_day and not is_contacted_in_past

    response = %{
      total_post_contacted: total_post_contacted_successfully,
      to_be_warned: to_be_warned,
      to_be_restricted: to_be_restricted
    }

    response = add_warning_message(to_be_warned, response, total_post_contacted_successfully)
    response = add_restriction_message(to_be_restricted, response, is_post_restricted_by_owner)

    {response, to_be_restricted}
  end

  def fetch_number_of_brokers_contacted(contact_post_class, post_id, start_time_unix, end_time_unix) do
    contact_post_class
    |> where([crp], crp.post_id == ^post_id)
    |> where(
      [crp],
      ^start_time_unix <= fragment("ROUND(extract(epoch from ?))", crp.inserted_at) and
        ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", crp.inserted_at)
    )
    |> Repo.aggregate(:count, :id)
  end

  def check_if_restricted_by_owner(true, _number_of_brokers_contacted, _is_contacted_in_past), do: false

  def check_if_restricted_by_owner(false, number_of_brokers_contacted, is_contacted_in_past) do
    not is_contacted_in_past and number_of_brokers_contacted >= @restriction_limit_for_unverified_property_per_day_by_owner
  end

  def is_post_contacted_in_past(broker_id, post_id, "rent") do
    count =
      ContactedRentalPropertyPost
      |> where([crp], crp.user_id == ^broker_id and crp.post_id == ^post_id and crp.count > 0)
      |> Repo.aggregate(:count, :id)

    count > 0
  end

  def is_post_contacted_in_past(broker_id, post_id, "resale") do
    count =
      ContactedResalePropertyPost
      |> where([crp], crp.user_id == ^broker_id and crp.post_id == ^post_id and crp.count > 0)
      |> Repo.aggregate(:count, :id)

    count > 0
  end

  def add_warning_message(false, response, _total_post_contacted), do: response

  def add_warning_message(true, response, total_post_contacted) do
    Map.merge(response, %{
      warning_message: "You have #{@restriction_limit_for_post_contact_per_day - total_post_contacted} contacts left for the day"
    })
  end

  def add_restriction_message(false, response, _is_post_restricted_by_owner), do: response

  def add_restriction_message(true, response, is_post_restricted_by_owner) do
    case is_post_restricted_by_owner do
      true ->
        Map.merge(response, %{
          restricted_message: "Owner has restricted the number of contacts for the day, Please try tomorrow"
        })

      false ->
        Map.merge(response, %{
          restricted_message: "You have exhausted the number of contacts for the day, Please try tomorrow"
        })
    end
  end
end
