defmodule BnApis.Posts.RawPostLogs do
  alias BnApis.Repo
  alias BnApis.Posts.Schema.RawPostLog

  def log(raw_entity_type, raw_entity_id, user_map, changes) do
    params = %{
      "user_id" => user_map[:user_id],
      "user_type" => user_map[:user_type],
      "changes" => changes,
      "raw_entity_type" => raw_entity_type,
      "raw_entity_id" => raw_entity_id
    }

    %RawPostLog{}
    |> RawPostLog.changeset(params)
    |> Repo.insert!()
  end
end
