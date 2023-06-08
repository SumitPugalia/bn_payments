defmodule BnApis.Reasons do
  @moduledoc """
  The Reasons context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Reasons.ReasonType

  @doc """
  Returns the list of reasons_types.

  ## Examples

      iex> list_reasons_types()
      [%ReasonType{}, ...]

  """
  def list_reasons_types do
    ReasonType
    |> preload(:reasons)
    |> Repo.all()
  end

  @doc """
  Gets a single reason_type.

  Raises `Ecto.NoResultsError` if the Reason type does not exist.

  ## Examples

      iex> get_reason_type!(123)
      %ReasonType{}

      iex> get_reason_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_reason_type!(id), do: Repo.get!(ReasonType, id)

  @doc """
  Creates a reason_type.

  ## Examples

      iex> create_reason_type(%{field: value})
      {:ok, %ReasonType{}}

      iex> create_reason_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_reason_type(attrs \\ %{}) do
    %ReasonType{}
    |> ReasonType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a reason_type.

  ## Examples

      iex> update_reason_type(reason_type, %{field: new_value})
      {:ok, %ReasonType{}}

      iex> update_reason_type(reason_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_reason_type(%ReasonType{} = reason_type, attrs) do
    reason_type
    |> ReasonType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ReasonType.

  ## Examples

      iex> delete_reason_type(reason_type)
      {:ok, %ReasonType{}}

      iex> delete_reason_type(reason_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_reason_type(%ReasonType{} = reason_type) do
    Repo.delete(reason_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking reason_type changes.

  ## Examples

      iex> change_reason_type(reason_type)
      %Ecto.Changeset{source: %ReasonType{}}

  """
  def change_reason_type(%ReasonType{} = reason_type) do
    ReasonType.changeset(reason_type, %{})
  end

  alias BnApis.Reasons.Reason

  @doc """
  Returns the list of reasons.

  ## Examples

      iex> list_reasons()
      [%Reason{}, ...]

  """
  def list_reasons do
    Repo.all(Reason)
  end

  @doc """
  Gets a single reason.

  Raises `Ecto.NoResultsError` if the Reason does not exist.

  ## Examples

      iex> get_reason!(123)
      %Reason{}

      iex> get_reason!(456)
      ** (Ecto.NoResultsError)

  """
  def get_reason!(id), do: Repo.get!(Reason, id)

  @doc """
  Creates a reason.

  ## Examples

      iex> create_reason(%{field: value})
      {:ok, %Reason{}}

      iex> create_reason(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_reason(attrs \\ %{}) do
    %Reason{}
    |> Reason.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a reason.

  ## Examples

      iex> update_reason(reason, %{field: new_value})
      {:ok, %Reason{}}

      iex> update_reason(reason, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_reason(%Reason{} = reason, attrs) do
    reason
    |> Reason.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Reason.

  ## Examples

      iex> delete_reason(reason)
      {:ok, %Reason{}}

      iex> delete_reason(reason)
      {:error, %Ecto.Changeset{}}

  """
  def delete_reason(%Reason{} = reason) do
    Repo.delete(reason)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking reason changes.

  ## Examples

      iex> change_reason(reason)
      %Ecto.Changeset{source: %Reason{}}

  """
  def change_reason(%Reason{} = reason) do
    Reason.changeset(reason, %{})
  end
end
