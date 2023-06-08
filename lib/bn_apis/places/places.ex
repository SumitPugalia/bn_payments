defmodule BnApis.Places do
  @moduledoc """
  The Places context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Places.Locality

  @doc """
  Returns the list of localities.

  ## Examples

      iex> list_localities()
      [%Locality{}, ...]

  """
  def list_localities do
    Repo.all(Locality)
    |> Enum.map(&add_transaction_filter_range/1)
  end

  @doc """
  Gets a single locality.

  Raises `Ecto.NoResultsError` if the Locality does not exist.

  ## Examples

      iex> get_locality!(123)
      %Locality{}

      iex> get_locality!(456)
      ** (Ecto.NoResultsError)

  """
  def get_locality!(id), do: Repo.get!(Locality, id)

  @doc """
  Creates a locality.

  ## Examples

      iex> create_locality(%{field: value})
      {:ok, %Locality{}}

      iex> create_locality(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_locality(attrs \\ %{}) do
    %Locality{}
    |> Locality.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a locality.

  ## Examples

      iex> update_locality(locality, %{field: new_value})
      {:ok, %Locality{}}

      iex> update_locality(locality, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_locality(%Locality{} = locality, attrs) do
    locality
    |> Locality.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Locality.

  ## Examples

      iex> delete_locality(locality)
      {:ok, %Locality{}}

      iex> delete_locality(locality)
      {:error, %Ecto.Changeset{}}

  """
  def delete_locality(%Locality{} = locality) do
    Repo.delete(locality)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking locality changes.

  ## Examples

      iex> change_locality(locality)
      %Ecto.Changeset{source: %Locality{}}

  """
  def change_locality(%Locality{} = locality) do
    Locality.changeset(locality, %{})
  end

  alias BnApis.Places.SubLocality

  @doc """
  Returns the list of sub_localities.

  ## Examples

      iex> list_sub_localities()
      [%SubLocality{}, ...]

  """
  def list_sub_localities do
    Repo.all(SubLocality)
  end

  @doc """
  Gets a single sub_locality.

  Raises `Ecto.NoResultsError` if the Sub locality does not exist.

  ## Examples

      iex> get_sub_locality!(123)
      %SubLocality{}

      iex> get_sub_locality!(456)
      ** (Ecto.NoResultsError)

  """
  def get_sub_locality!(id), do: Repo.get!(SubLocality, id)

  @doc """
  Creates a sub_locality.

  ## Examples

      iex> create_sub_locality(%{field: value})
      {:ok, %SubLocality{}}

      iex> create_sub_locality(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_sub_locality(attrs \\ %{}) do
    %SubLocality{}
    |> SubLocality.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a sub_locality.

  ## Examples

      iex> update_sub_locality(sub_locality, %{field: new_value})
      {:ok, %SubLocality{}}

      iex> update_sub_locality(sub_locality, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_sub_locality(%SubLocality{} = sub_locality, attrs) do
    sub_locality
    |> SubLocality.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a SubLocality.

  ## Examples

      iex> delete_sub_locality(sub_locality)
      {:ok, %SubLocality{}}

      iex> delete_sub_locality(sub_locality)
      {:error, %Ecto.Changeset{}}

  """
  def delete_sub_locality(%SubLocality{} = sub_locality) do
    Repo.delete(sub_locality)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking sub_locality changes.

  ## Examples

      iex> change_sub_locality(sub_locality)
      %Ecto.Changeset{source: %SubLocality{}}

  """
  def change_sub_locality(%SubLocality{} = sub_locality) do
    SubLocality.changeset(sub_locality, %{})
  end

  def get_locality_suggestions(search_text) do
    Locality.search_locality_query(search_text)
    |> Repo.all()
    |> Enum.map(&add_transaction_filter_range/1)
  end

  alias BnApis.Transactions.Transaction

  def add_transaction_filter_range(locality) do
    info = Transaction.get_ranges_for_transactions(locality.id)
    locality |> Map.merge(info) |> Map.delete(:id)
  end
end
