defmodule BnApis.Reminder.Status do
  @created %{id: 1, name: "Created"}
  @completed %{id: 2, name: "Completed"}
  @cancelled %{id: 3, name: "Cancelled"}

  def status_list() do
    [
      @created,
      @completed,
      @cancelled
    ]
  end

  def created(), do: @created
  def completed(), do: @completed
  def cancelled(), do: @cancelled
end
