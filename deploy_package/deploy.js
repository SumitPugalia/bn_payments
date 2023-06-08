const fs = require("fs");
const path = require("path");
const name = "apis";
const yaml = require("js-yaml");
const child_process = require("child_process");
const supervisorHelper = require("./supervisor.conf")

const config_map = {
  "application.yml": {
    "source": "dply/config/prod.exs",
    "destination": "config/prod.exs"
  }
}

const flattenObj = (ob) => {
  let result = {};
  for (const i in ob) {
    if ((typeof ob[i]) === 'object' && !Array.isArray(ob[i])) {
      const temp = flattenObj(ob[i]);
      for (const j in temp) {
        result[i + '.' + j] = temp[j];
      }
    }
    else {
      result[i] = ob[i];
    }
  }
  return result;
};

const append_key_value = (val) => {
  if (typeof(val) == "string") {
    return `"${val}"`
  }
  return val
}

function escapeRegExp(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); // $& means the whole matched string
}

const prepare_config = () => {
    for (const file in config_map) {
      const source_file_path = path.resolve(`./${config_map[file]["source"]}`);
      const source_exists = fs.existsSync(source_file_path);
      let source_content = fs.readFileSync(source_file_path).toString();
      const destination_file_path = path.resolve(`./${config_map[file]["destination"]}`);
      const config_file_path = path.resolve(`../config/${file}`);
      const config_exists = fs.existsSync(config_file_path);
      if (source_exists && config_exists) {
        const file_json = yaml.load(fs.readFileSync(config_file_path, 'utf8'), {json: true});
        const flatten_object =  flattenObj(file_json);
        for (const key_to_replace in flatten_object) {
          source_content = source_content.replace(new RegExp(escapeRegExp(`<%= config["${key_to_replace}"] %>`), 'g'), append_key_value(flatten_object[key_to_replace]))
        }
      }
      fs.writeFileSync(destination_file_path, source_content, { flag: "w+" });
    }
}

const pre_deploy = () => {
  child_process.execSync("git pull origin master", {stdio: 'inherit'});
  child_process.execSync("MIX_ENV=prod mix local.rebar --force", {stdio: 'inherit'});
  child_process.execSync("MIX_ENV=prod mix local.hex --force", {stdio: 'inherit'});
  child_process.execSync("MIX_ENV=prod mix deps.get --force", {stdio: 'inherit'});
  child_process.execSync("MIX_ENV=prod mix compile", {stdio: 'inherit'});
  child_process.execSync("MIX_ENV=prod mix assets.deploy", {stdio: 'inherit'});
  child_process.execSync("MIX_ENV=prod mix ecto.setup", {stdio: 'inherit'});
}

const get_jobs = () => {
  try {
    const result = child_process.execSync("supervisorctl -c tmp/supervisor.conf 'status'").toString();
    const existingJobs = result.split("\n")
    if (existingJobs.length) {
      const firstElement = existingJobs[0].split("   ")[0]
      if ((firstElement.indexOf("mix_server") !== -1) || (firstElement.indexOf("scheduler") !== -1)) {
        const procs = []
        existingJobs.forEach((item, i) => {
          if (item.split("   ")[0].split(":")[0] !== '') {
            procs.push({name: item.split("   ")[0].split(":")[0], group: item.split("   ")[0].split(":")[1], status: item.split("   ")[1]})
          }
        });
        return procs
      }
      return []
    }
    return []
  }catch(e) {
    return []
  }
}

const start_supervisor = () => {
  const supervisor_config_file_path = path.resolve(`../config/supervisor.yml`);
  const supervisor_config_file_exists = fs.existsSync(supervisor_config_file_path);
  const file_json = yaml.load(fs.readFileSync(supervisor_config_file_path, 'utf8'), {json: true});
  const current_dir = process.cwd()
  /*
    mix_server: true
    scheduler: true
  */
  if (!fs.existsSync(`${current_dir}/tmp`)) {
    fs.mkdirSync(`${current_dir}/tmp`)
  }
  if (!fs.existsSync(`${current_dir}/log`)) {
    fs.mkdirSync(`${current_dir}/log`)
  }
  if (!fs.existsSync(`${current_dir}/tmp/pids`)) {
    fs.mkdirSync(`${current_dir}/tmp/pids`)
  }
  if (!fs.existsSync(`${current_dir}/tmp/sockets`)) {
    fs.mkdirSync(`${current_dir}/tmp/sockets`)
  }
  if (!fs.existsSync(`${current_dir}/log/mix_server.log`)) {
    fs.writeFileSync(`${current_dir}/log/mix_server.log`, "Starting mix_server logs ... ", { flag: "w+" })
  }
  if (!fs.existsSync(`${current_dir}/log/scheduler.log`)) {
    fs.writeFileSync(`${current_dir}/log/scheduler.log`, "Starting scheduler logs ... ", { flag: "w+" })
  }
  if (!fs.existsSync(`${current_dir}/log/supervisord.log`)) {
    fs.writeFileSync(`${current_dir}/log/supervisord.log`, "Starting supervisord logs ... ", { flag: "w+" })
  }
  const supervisor_config = supervisorHelper.get_config(current_dir, file_json.scheduler)
  const existingJobs = get_jobs()
  fs.writeFileSync(`${current_dir}/tmp/supervisor.conf`, supervisor_config, { flag: "w+" });
  rolling_restart(existingJobs)
}

const sleep = async (t) => {
  await new Promise((resolve) => {
    setTimeout(resolve, t)
  })
}


const startJobs = async (jobs) => {
  if (jobs.length) {
    for (const i in jobs) {
      const item = jobs[i]
      if (item.name && item.name !== '' && item.status){
        await sleep(1500)
        child_process.execSync(`supervisorctl -c tmp/supervisor.conf 'start ${item.name}:${item.group}'`, {stdio: 'inherit'});
      }
    }
  }
  child_process.execSync("supervisorctl -c tmp/supervisor.conf status", {stdio: 'inherit'});
}

const rolling_restart = async (existingJobs) => {
  if (existingJobs.length) {
    child_process.execSync("supervisorctl -c tmp/supervisor.conf 'reload'");
    await sleep(4000)
    let jobs = get_jobs()
    startJobs(jobs)
  } else {
    let jobs = get_jobs()
    if (jobs.length) {
      for (const item in jobs) {
        if (item.status == "STOPPED" || item.status == "FATAL" || item.status == "BACKOFF") {
          child_process.execSync(`supervisorctl -c tmp/supervisor.conf 'remove ${item.name}'`, {stdio: 'inherit'});
        } else {
          child_process.execSync(`supervisorctl -c tmp/supervisor.conf 'add ${item.name}'`, {stdio: 'inherit'});
        }
      }
    }
    child_process.execSync("supervisord -c tmp/supervisor.conf", {stdio: 'inherit'});
    jobs = get_jobs()
    startJobs(jobs)
  }
}


prepare_config()
pre_deploy()
start_supervisor()
