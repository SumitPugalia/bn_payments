defmodule BnApis.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # List all child processes to be supervised
    children =
      [
        BnApis.Repo,
        BnApisWeb.Telemetry,
        {Phoenix.PubSub, name: BnApis.PubSub},
        BnApisWeb.Endpoint,
        Exq,
        {Cachex, name: :bn_apis_cache}
      ] ++ maybe_add_scheduler()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    :telemetry.attach(
      "appsignal-ecto",
      [:bn_apis, :repo, :query],
      &Appsignal.Ecto.handle_event/4,
      nil
    )

    :telemetry.attach(
      "bn.apis-ecto",
      [:bn_apis, :repo, :query],
      &BnApis.Dashboard.Ecto.handle_event/4,
      nil
    )

    opts = [strategy: :one_for_one, name: BnApis.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BnApisWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_add_scheduler do
    if System.get_env("SCHEDULER") do
      [
        BnApis.Scheduler
      ]
    else
      []
    end
  end
end
