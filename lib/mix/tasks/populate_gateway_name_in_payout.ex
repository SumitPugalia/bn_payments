defmodule Mix.Tasks.PopulateGatewayNameInPayout do
  use Mix.Task

  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Rewards.Payout
  alias BnApis.Rewards.EmployeePayout

  @shortdoc "populate gateway_name to existing payouts"
  def run(_) do
    Mix.Task.run("app.start", [])

    Repo.transaction(
      fn ->
        from(p in Payout)
        |> Repo.stream()
        |> Stream.each(fn data -> Payout.changeset(data, %{gateway_name: "razorpay"}) |> Repo.update!() end)
        |> Stream.run()
      end,
      timeout: :infinity
    )

    Repo.transaction(
      fn ->
        from(p in EmployeePayout)
        |> Repo.stream()
        |> Stream.each(fn data -> EmployeePayout.changeset(data, %{gateway_name: "razorpay"}) |> Repo.update!() end)
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end
end
