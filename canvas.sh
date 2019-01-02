#!/bin/bash

set -e



OS="$(uname)"

if [[ "$USER" == 'root' ]]; then
  echo 'Please do not run this script as root!'
  echo "I'll ask for your sudo password if I need it."
  exit 1
fi

if [[ $OS == 'Darwin' ]]; then
  install='brew install'
  dependencies='docker docker-composey'
elif [[ $OS == 'Linux' ]]; then
  install='sudo apt-get update && sudo apt-get install -y'
  dependencies='docker-compose'
else
  echo 'This script only supports MacOS and Linux :('
  exit 1
fi


function message {
  echo ''
  echo "$BOLD> $*$NORMAL"
}

function prompt {
  read -r -p "$1 " "$2"
}

function confirm_command {
  prompt "OK to run '$*'? [y/n]" confirm
  [[ ${confirm:-n} == 'y' ]] || return 1
  eval "$*"
}


function install_dependencies {
  local packages=()
  for package in $dependencies; do
    installed "$package" || packages+=("$package")
  done
  [[ ${#packages[@]} -gt 0 ]] || return 0

  message "First, we need to install some dependencies."
  if [[ $OS == 'Darwin' ]]; then
    if ! installed brew; then
      echo 'We need homebrew to install dependencies, please install that first!'
      echo 'See https://brew.sh/'
      exit 1
    fi
  elif [[ $OS == 'Linux' ]] && ! installed apt-get; then
    echo 'This script only supports Debian-based Linux (for now - contributions welcome!)'
    exit 1
  fi
  confirm_command "$install ${packages[*]}"
}

function start_docker_daemon {
  service docker status &> /dev/null && return 0
  prompt 'The docker daemon is not running. Start it? [y/n]' confirm
  [[ ${confirm:-n} == 'y' ]] || return 1
  sudo service docker start
  sleep 1 # wait for docker daemon to start
}

function setup_docker_as_nonroot {
  docker ps &> /dev/null && return 0
  message 'Setting up docker for nonroot user...'

  if ! id -Gn "$USER" | grep -q '\bdocker\b'; then
    message "Adding $USER user to docker group..."
    confirm_command "sudo usermod -aG docker $USER" || true
  fi

  message 'We need to login again to apply that change.'
  confirm_command "exec sg docker -c $0"
}

function create_volumes {
    docker volume create --name canvas-postgresql --driver local
    docker volume create --name canvas-redis --driver local
}

function run_db_con {
    docker-compose up -d db
    sleep 2 # wait for DB contener is up
}

function database_exists {
  docker-compose run --rm app \
    bundle exec rails runner 'ActiveRecord::Base.connection' &> /dev/null
}

function create_db {
  if database_exists; then
    message \
'An existing database was found.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
This script will destroy ALL EXISTING DATA if it continues
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
  prompt "Do you want recreate DB? [y/n]" confirm
  [[ ${confirm:-n} == 'y' ]] || return 1
    message 'About to run "bundle exec rake db:drop"'
    prompt "type NUKE in all caps: " nuked
    [[ ${nuked:-n} == 'NUKE' ]] || exit 1
    docker-compose run --rm -e DISABLE_DATABASE_ENVIRONMENT_CHECK=1 app bundle exec rake db:drop
  fi

  message "Creating new database"
  docker-compose run --rm app bundle exec rake db:create db:initial_setup
}

function gen_assets {
    docker-compose run --rm app bundle exec rake \
    canvas:compile_assets_dev \
    brand_configs:generate_and_upload_all
}

function build_app {
    docker-compose up -d --build
}
function run_app {
    if database_exists; then 
        docker-compose up -d 
    else
       prompt 'First you have to setup Canvas environment, do you want to do it now? [y/n]' confirm
            [[ ${confirm:-n} == 'y' ]] || return 1
            setup_canvas
    fi
}

function stop_app {
    docker-compose stop
}

function fix_db {
  docker-compose run -e PGDATABASE=canvas -e PGUSER=canvas -e PGHOST=db -e PGPASSWORD=canvas --rm db psql -c "UPDATE attachments set content_type='application/x-javascript' WHERE content_type='text/javascript';"
}


function setup_canvas {
  message 'Now we can set up Canvas!'
  create_volumes
  run_db_con
  create_db
  message 'DB connfig Done'
  message 'Start generate assets, this can take up to 30 minutes'
  gen_assets
  message 'Start all services'
  build_app
  message 'Canvas App is accesible https://localhost
           MailHog (catches all out going mail from canvas) is accessible at http://localhost:8901/
           Web browser can show Warning about security, becaouse you are using self signed certyficate, 
           more information about this is in README.md file. '
}


function menu {
echo '

Welcome! This script will guide you through the process of setting up a
Canvas environment with docker, and allow you to manage it.
'
prompt 'Do you want to setup new Canvas environment [y/n]' confirm
if [[ ${confirm:-n} == 'y' ]]; then 
    setup_canvas
elif prompt 'Do you want to fix DB after adding themes [y/n]' confirm
    [[ ${confirm:-n} == 'y' ]]; then
    fix_db
elif prompt 'Do you want to stop Canvas environment [y/n]' confirm 

 [[ ${confirm:-n} == 'y' ]]; then
    stop_app
elif
prompt 'Do you want to start Canvas environment [y/n]' confirm
[[ ${confirm:-n} == 'y' ]]; then
    run_app
fi

}
menu