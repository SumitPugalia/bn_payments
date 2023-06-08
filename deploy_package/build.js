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



prepare_config()
pre_deploy()
