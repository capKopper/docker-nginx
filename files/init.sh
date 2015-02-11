#!/bin/bash
set -eo pipefail

_log(){
  declare BLUE="\e[32m" WHITE="\e[39m"
  echo -e "$(date --iso-8601=s)${BLUE} (info)${WHITE}:" $@
}

_error(){
  declare RED="\e[91m" WHITE="\e[39m"
  echo -e "$(date --iso-8601=s)${RED} (error)${WHITE}:" $@
  exit 1
}

_debug()
{
  declare BLUE="\e[36m" WHITE="\e[39m"
  echo -e "$(date --iso-8601=s)${BLUE} (debug)${WHITE}:" $@
}


usage(){
  # """
  # Usage.
  # """
  echo "Usage: init.sh <username> <uid>"
  exit 1
}

check_user(){
  #"""
  # Check if the given user is present.
  # If not add it.
  #""""
  local username=$1
  local uid=$2

  _log "Checking that user '$username' exists ..."
  if [ $(grep -c $username /etc/passwd) == "0" ]; then
    _debug "create user '$username'"
    useradd -u $uid -s /bin/bash $1
  fi
}

configure_nginx(){
  # """
  # Configure nginx to run with the given user.
  # """"
  local username=$1
  local listen_port="8080"

  _log "Configure nginx process to run with '$username' ..."

  _debug "delete 'user' directive from nginx main config file"
  sed -i 's/^user.*;$//g' /etc/nginx/nginx.conf

  _debug "change nginx pid file location"
  sed -i 's@^pid.*;$@pid /tmp/nginx.pid;@g' /etc/nginx/nginx.conf

  _debug "set default listen port to $listen_port"
  sed -i 's/listen.*80;$/listen 8080;/g' /etc/nginx/conf.d/default.conf

  _debug "change owner and group ($1:$1) for log and cache directories"
  chown -R $username:$username /var/log/nginx &&
  chown -R $username:$username /var/cache/nginx/

  if mountpoint -q "/var/log/nginx"; then
    _debug "/var/log/nginx is a mountpoint"
  else
    # removing base container log files symlinks to /dev/stdout and /dev/stderr
    _debug "removing files into /var/log/nginx"
    rm -fr /var/log/nginx/*
  fi
}

configure_runit(){
  # """
  # Configure runit to launch nginx service.
  # """
  local username=$1
  local sv_dir="/etc/sv/nginx"
  local sv_run=${sv_dir}"/run"

  _log "Configure runit to launch nginx ..."

  if [ ! -d $sv_dir ]; then
    _debug "add nginx './run' script"
    mkdir $sv_dir
    cat > $sv_run << EOF
#!/bin/bash
exec chpst -u $username /usr/sbin/nginx -g 'daemon off;' 2>&1
EOF
    chmod u+x $sv_run
  fi
}

activate_nginx_service(){
  local sv_dir="/etc/sv/nginx"
  # """
  # Activate the given service.
  # """

  _log "Activating nginx service ..."
  ln -s $sv_dir /etc/service
}

start_runit(){
  # """
  # Start runit.
  # """
  _log "Starting runit ..."
  runsvdir /etc/service
}


main(){
  if [ $# -ne 2 ]; then
    usage
  fi

  check_user $@
  configure_nginx $1
  configure_runit $1
  activate_nginx_service
  start_runit
}


main $@
