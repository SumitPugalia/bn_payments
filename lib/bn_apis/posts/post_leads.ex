defmodule BnApis.Posts.PostLeads do
  alias BnApis.Repo
  alias BnApis.Posts.Schema.PostLead
  alias BnApis.Helpers.SlashHelper

  def create_lead_and_push_to_slash(params) do
    {status, post_lead} =
      %PostLead{}
      |> PostLead.changeset(params)
      |> Repo.insert()

    if status == :ok do
      push_to_slash(post_lead)
    end

    {status, post_lead}
  end

  def update(params = %{"id" => id}) do
    post_lead = Repo.get_by(PostLead, id: id)

    case post_lead do
      nil ->
        {:error, "Post Lead can't be found with id #{id}"}

      post_lead ->
        PostLead.changeset(post_lead, params)
        |> Repo.update()
    end
  end

  def push_to_slash(post_lead) do
    post_lead_details = %{
      "lead_id" => post_lead.post_uuid,
      "lead_type" => post_lead.post_type,
      "customer_number" => post_lead.phone_number,
      "source" => post_lead.source,
      "table_name" => PostLead.schema_name(),
      "table_uniq_identifier" => post_lead.id
    }

    SlashHelper.async_push_to_slash(post_lead_details)
  end
end
