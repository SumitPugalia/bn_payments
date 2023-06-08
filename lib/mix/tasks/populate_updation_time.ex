defmodule Mix.Tasks.PopulateUpdationTime do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Posts.{RentalClientPost, RentalPropertyPost, ResaleClientPost, ResalePropertyPost}

  @shortdoc "populate updation time"
  def run(_) do
    Mix.Task.run("app.start", [])
    populate_rental_client_posts()
    populate_rental_property_posts()
    populate_resale_client_posts()
    populate_resale_property_posts()
  end

  def populate_rental_client_posts() do
    RentalClientPost
    |> Repo.all()
    |> Enum.each(fn p ->
      p |> RentalClientPost.changeset(%{updation_time: p.updated_at}) |> Repo.update()
    end)
  end

  def populate_rental_property_posts() do
    RentalPropertyPost
    |> Repo.all()
    |> Enum.each(fn p ->
      p |> RentalPropertyPost.changeset(%{updation_time: p.updated_at}) |> Repo.update()
    end)
  end

  def populate_resale_client_posts() do
    ResaleClientPost
    |> Repo.all()
    |> Enum.each(fn p ->
      p |> ResaleClientPost.changeset(%{updation_time: p.updated_at}) |> Repo.update()
    end)
  end

  def populate_resale_property_posts() do
    ResalePropertyPost
    |> Repo.all()
    |> Enum.each(fn p ->
      p |> ResalePropertyPost.changeset(%{updation_time: p.updated_at}) |> Repo.update()
    end)
  end
end
