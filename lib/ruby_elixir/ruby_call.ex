defmodule RubyElixir.RubyCall do
  use Export.Ruby

  def call(filename, function_name, options \\ []) do
    {:ok, ruby} = Ruby.start(ruby_lib: Path.expand("lib/ruby"))

    ruby
    |> Ruby.call(filename, function_name, options)
  end
end
