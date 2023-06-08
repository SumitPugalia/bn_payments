const crypto = require("crypto");
const jobsHelper = require('../config/jobs.js');

const jobs_template = ({group_suffix, name, command, current_dir, stdout_logfile, environment, instances}) => {
  return `
[program:${name}.${group_suffix}]
process_name=${name}_%(process_num)02d
command=${command}
directory=${current_dir}
numprocs=${instances}
autostart=false
autorestart=true
startsecs=1
startretries=3
stopsignal=TERM
stopwaitsecs=10
stopasgroup=false
killasgroup=true
stdout_logfile=${stdout_logfile}
stdout_logfile_maxbytes=0
redirect_stderr=true
environment=${environment}
`
}


const get_config = (current_dir, has_scheduler) => {
  const group_suffix = crypto.randomBytes(3).toString('hex');
  const stdout_logfile = `${current_dir}/log/scheduler.log`;

  const jobs = jobsHelper.get_jobs(has_scheduler)

  const job_string = jobs.map((jb) => {
    return jobs_template({ group_suffix, name: jb.name, command: jb.command, current_dir, environment: jb.environment, stdout_logfile: `${current_dir}${jb.stdout_logfile}`, instances: jb.instances})
  }).join("")

  return `[unix_http_server]
file=${current_dir}/tmp/sockets/supervisor.sock
chmod=0770

[supervisord]
logfile=${current_dir}/log/supervisord.log
loglevel=info
pidfile=${current_dir}/tmp/pids/supervisor.pid
logfile_maxbytes=0
directory=${current_dir}

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix://${current_dir}/tmp/sockets/supervisor.sock

${job_string}
`

}

module.exports = {
  get_config
}
