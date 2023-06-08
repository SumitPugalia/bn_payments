defmodule BnApisWeb.CallLogView do
  use BnApisWeb, :view
  alias BnApisWeb.CallLogView
  alias BnApis.Helpers.{Time, S3Helper}

  def render("index.json", %{call_logs: call_logs}) do
    %{data: render_many(call_logs, CallLogView, "call_log.json")}
  end

  def render("show.json", %{call_log: call_log}) do
    %{data: render_one(call_log, CallLogView, "call_log.json")}
  end

  def render("all_call_logs.json", %{call_logs: call_logs, has_more_call_logs: has_more_call_logs}) do
    %{
      call_logs: render_many(call_logs, CallLogView, "call_log.json"),
      has_more_call_logs: has_more_call_logs
    }
  end

  def render("call_log.json", %{call_log: call_log}) do
    contact_details =
      case call_log do
        %{type: "story"} ->
          call_log.contact_details

        _ ->
          case call_log.contact_details do
            %{uuid: nil} ->
              call_log.contact_details_from_universe

            %{uuid: _uuid} = contact_details ->
              profile_pic_url =
                if contact_details.profile_pic_url && contact_details.profile_pic_url["url"] do
                  contact_details.profile_pic_url["url"] |> S3Helper.get_imgix_url()
                else
                  nil
                end

              %{contact_details | profile_pic_url: profile_pic_url}
          end
      end

    call_log =
      call_log
      |> Map.merge(%{
        start_time: call_log.start_time |> Time.naive_to_epoch(),
        contact_details: contact_details,
        inserted_at: call_log.inserted_at |> Time.naive_second_to_millisecond(),
        inserted_at_unix: call_log.inserted_at |> Time.naive_to_epoch_in_sec()
      })

    call_log |> Map.delete(:contact_details_from_universe)
  end

  def render("call_log_with_contact.json", %{call_log: call_log, feedback_session_id: feedback_session_id}) do
    call_log = render("call_log.json", %{call_log: call_log})

    call_log
    |> Map.merge(%{
      feedback_session_id: feedback_session_id
    })
  end
end
