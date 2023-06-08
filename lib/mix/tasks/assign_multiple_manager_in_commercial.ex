defmodule Mix.Tasks.AssignMultipleManagerInCommercial do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Commercials.CommercialPropertyPost

  @shortdoc "Assiging Multiple manager from existing Assigned manger field"
  def run(_) do
    Mix.Task.run("app.start", [])

    CommercialPropertyPost
    |> where([c], not is_nil(c.assigned_manager_id))
    |> select([c], %{id: c.id, assigned_manager_ids: c.assigned_manager_ids, assigned_manager_id: c.assigned_manager_id})
    |> Repo.all()
    |> Enum.each(fn p -> add_in_manager_ids(p) end)
  end

  def add_in_manager_ids(post) do
    updated_ids =
      if Enum.member?(post.assigned_manager_ids, post.assigned_manager_id),
        do: post.assigned_manager_ids,
        else: post.assigned_manager_ids ++ [post.assigned_manager_id]

    from(u in CommercialPropertyPost, where: u.id == ^post.id)
    |> Repo.update_all(set: [assigned_manager_ids: updated_ids])
  end
end
