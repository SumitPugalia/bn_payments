defmodule BnApisWeb.V1.Posts.BucketView do
  use BnApisWeb, :view
  alias BnApisWeb.V1.Posts.BucketView
  alias BnApis.Helpers.Time

  def render("list.json", %{buckets: buckets, has_more_buckets: has_more_buckets, badge_count: badge_count}) do
    %{buckets: render_many(buckets, BucketView, "bucket.json"), has_more_buckets: has_more_buckets, badge_count: badge_count}
  end

  def render("bucket.json", %{bucket: bucket}) do
    %{
      id: bucket.id,
      name: bucket.name,
      number_of_matching_properties: bucket.number_of_matching_properties,
      new_number_of_matching_properties: bucket.new_number_of_matching_properties,
      inserted_at: bucket.inserted_at |> Time.naive_to_epoch(),
      filters: render_filter(bucket.filters)
    }
  end

  def render_filter(filter) do
    %{
      post_type: filter.post_type,
      configuration_type: filter.configuration_type,
      location_name: filter.location_name
    }
    |> Enum.to_list()
    |> Enum.filter(fn {_key, val} -> !is_nil(val) end)
    |> Enum.into(%{})
  end
end
