defmodule BnApis.Organizations.ValidRera do
  use Ecto.Schema
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Schemas.ValidRera

  def create(rera_id, rera_name, rera_file) do
    attrs = %{
      rera_id: rera_id,
      rera_name: rera_name,
      rera_file: rera_file
    }

    %ValidRera{}
    |> ValidRera.changeset(attrs)
    |> case do
      {:error, changeset} ->
        {:error, changeset}

      {:ok, changeset} ->
        Repo.insert(changeset)
    end
  end

  def update(valid_rera, rera_id, rera_name, rera_file) do
    attrs = %{
      rera_id: rera_id,
      rera_name: rera_name,
      rera_file: rera_file
    }

    valid_rera
    |> ValidRera.changeset(attrs)
    |> case do
      {:error, changeset} ->
        {:error, changeset}

      {:ok, changeset} ->
        Repo.update(changeset)
    end
  end

  def fetch(rera_id) do
    ValidRera
    |> where([r], fragment("LOWER(?) LIKE LOWER(?)", r.rera_id, ^rera_id))
    |> Repo.one()
  end
end
