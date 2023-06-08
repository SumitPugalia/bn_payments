const mix_server = {
  name: "mix_server",
  command: "mix phx.server",
  environment: "PORT=40%(process_num)02d,MIX_ENV=prod",
  instances: 1,
  stdout_logfile: "/log/mix_server.log"
}

const scheduler = {
  name: "scheduler",
  command: "mix phx.server",
  environment: "MIX_ENV=prod,SCHEDULER=true",
  instances: 1,
  stdout_logfile: "/log/scheduler.log"
}

const get_jobs = (has_scheduler = false) => {
  if (has_scheduler) {
    return [
      mix_server,
      scheduler
    ]
  }
  return [mix_server]
}

module.exports = {
  get_jobs
}
