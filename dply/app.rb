config_map({
  "config/prod.exs" => "prod.exs",
  "config/sv.rb" => "sv.rb"
})

test do
end

build do
end

deploy :git do
  set_env "MIX_ENV", "prod"
  sh "mix local.rebar --force"
  sh "mix local.hex --force"
  sh "mix deps.get --force"
  sh "mix compile"
  sh "mix assets.deploy"
  sh "mix ecto.setup"
  sh "sv rr"
end

deploy :archive do

end

reload do
  set_env "MIX_ENV", "prod"
  sh "sv rr"
end

reopen_logs do
  sh "sv reopen_logs"
  sh "sv rr"
end

stop do
  sh "sv stop"
end
