defmodule BnApis.Repo do
  use Ecto.Repo,
    otp_app: :bn_apis,
    adapter: Ecto.Adapters.Postgres
end
