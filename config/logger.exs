import Config

# Contains a set of logger file backends to be used inside tuples, where the
# first element represents the environments in which the backend configuration
# should be used, and the second element is the backend configuration itself.

logger_file_backends = [
  {[:dev], {LoggerFileBackend, :debug}},
  {[:dev, :staging, :prod], {LoggerFileBackend, :info}},
  {[:dev, :staging, :prod], {LoggerFileBackend, :error}}
]

config :logger,
  backends:
    logger_file_backends
    |> Enum.filter(fn {environments, _backend} ->
      Enum.member?(environments, Mix.env())
    end)
    |> Enum.map(&elem(&1, 1))

# Configures Elixir's Logger
config :logger, :debug,
  path: "log/debug.log",
  format: "\n$date $time [$level] $metadata $message",
  level: :debug,
  metadata: [:reason]

config :logger, :info,
  path: "log/info.log",
  format: "\n$date $time [$level] $metadata $message",
  level: :info,
  metadata: [:reason]

config :logger, :error,
  path: "log/error.log",
  format: "\n$date $time [$level] $metadata $message",
  level: :error,
  metadata: [:reason]
