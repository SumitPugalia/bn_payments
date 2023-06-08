defmodule BnApis.RawPosts.PushSlashLeadWorker do
  alias BnApis.Posts.RawRentalPropertyPost
  alias BnApis.Posts.RawResalePropertyPost
  alias BnApis.Posts.PostLeads
  alias BnApis.Posts.Schema.PostLead
  alias BnApis.Helpers.SlashHelper

  @raw_resale_property_posts RawResalePropertyPost.schema_name()
  @raw_rental_property_posts RawRentalPropertyPost.schema_name()
  @post_leads PostLead.schema_name()

  def perform(
        _lead_details = %{
          "lead_id" => lead_id,
          "lead_type" => lead_type,
          "customer_number" => customer_number,
          "table_name" => table_name,
          "table_uniq_identifier" => table_uniq_identifier
        },
        token_id,
        user_map
      ) do
    response =
      SlashHelper.push_lead(
        lead_id,
        lead_type,
        token_id,
        customer_number
      )

    if response["STATUS_CODE"] == 200 do
      slash_reference_id = Integer.to_string(response["LOG_INFO"]["leadId"])
      update_leads(table_name, lead_id, slash_reference_id, table_uniq_identifier, user_map, token_id)
    end
  end

  def update_leads(_table_name, _lead_id, _slash_reference_id, _table_uniq_identifier, user_map, token_id, pushed_to_slash \\ true)

  def update_leads(@raw_rental_property_posts, lead_id, slash_reference_id, table_uniq_identifier, user_map, _token_id, pushed_to_slash) do
    RawRentalPropertyPost.update_post(user_map, %{
      "id" => table_uniq_identifier,
      "uuid" => lead_id,
      "pushed_to_slash" => pushed_to_slash,
      "slash_reference_id" => slash_reference_id
    })
  end

  def update_leads(@raw_resale_property_posts, lead_id, slash_reference_id, table_uniq_identifier, user_map, _token_id, pushed_to_slash) do
    RawResalePropertyPost.update_post(user_map, %{
      "id" => table_uniq_identifier,
      "uuid" => lead_id,
      "pushed_to_slash" => pushed_to_slash,
      "slash_reference_id" => slash_reference_id
    })
  end

  def update_leads(@post_leads, lead_id, slash_reference_id, table_uniq_identifier, _user_map, token_id, pushed_to_slash) do
    PostLeads.update(%{
      "id" => table_uniq_identifier,
      "post_uuid" => lead_id,
      "token_id" => token_id,
      "pushed_to_slash" => pushed_to_slash,
      "slash_reference_id" => slash_reference_id
    })
  end
end
