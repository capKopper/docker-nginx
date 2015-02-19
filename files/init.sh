#!/bin/bash
set -eo pipefail

_log(){
  declare BLUE="\e[32m" WHITE="\e[39m" BOLD="\e[1m" NORMAL="\e[0m"
  echo -e "$(date --iso-8601=s)${BLUE}${BOLD} (info)${WHITE}:" $@${NORMAL}
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

_warning(){
  declare RED="\e[91m" WHITE="\e[39m"
  echo -e "$(date --iso-8601=s)${RED} (warning)${WHITE}:" $@
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

  _log "Configure nginx process to run with '$username' ..."

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

configure_nginx_vhost(){
  # """
  # Configure nginx vhost(s).
  #
  # Use some environements variables (json format) to defined
  # - one default vhost (normal or in redirect mode)
  # - some additionnals vhosts
  # """
  local username=$1

  _log "Configure nginx vhost(s) ..."

  set_default_vhost "/tmp/nginx-tpl"
  set_additionnal_vhosts "/tmp/nginx-tpl" $username
}

set_default_vhost(){
  # """
  # Default vhost.
  # """
  local tpl_dir=$1
  local default_vhost_config=${DEFAULT_VHOST:-}
  local default_vhost_mode=$(echo $default_vhost_config | jq -r .mode)

  local vhost_file="/etc/nginx/sites-enabled/default"

  _log "'default' vhost"

  # set the default template suffix
  default_vhost_suffix=""
  if [ "$default_vhost_mode" != "" ]; then
    default_vhost_suffix="-"$default_vhost_mode
  fi
  local tpl_file=$tpl_dir/vhost_default$default_vhost_suffix.tpl

  # check if the default template file exists
  if [ ! -f $tpl_file ]; then
    _error "template file '$tpl_file' doesn't exists"
  fi

  # if redirect template is selected, check if redirection URL is given
  if [ "$default_vhost_mode" == "redirect" ]; then
    local default_vhost_redirect_url=$(echo $default_vhost_config | jq -r .redirect_url)
    if [ "$default_vhost_redirect_url" == "" ]; then
      _error "'redirect_url' attribute is not defined"
    fi
  fi

  _debug "=> based on template '$tpl_file'"
  cp $tpl_file /etc/nginx/sites-enabled/default
  sed -i -e 's|{{ REDIRECT_URL }}|'$default_vhost_redirect_url'|g' \
      $vhost_file
  _debug "=> '$vhost_file' has been written"
}

set_additionnal_vhosts(){
  # """
  # Additionnals vhosts.
  # """
  local tpl_dir=$1
  local customer=$2
  local vhosts_config=${VHOSTS:-}

  if [ -n "${VHOSTS}" ]; then
    vhost_index=0

    for i in $(echo $VHOSTS | jq -r '.[] | .hostname'); do
      # get config parameters
      vhost_hostname=$(echo $VHOSTS | jq -r '.['$vhost_index'].hostname')
      vhost_tpl=$(echo $VHOSTS | jq -r '.['$vhost_index'].template')
      vhost_php_backend=$(echo $VHOSTS | jq -r '.['$vhost_index'].php_backend')
      vhost_root=$(echo $VHOSTS | jq -r '.['$vhost_index'].root')
      # set template and vhost filenames
      tpl_file="$tpl_dir/vhost_$vhost_tpl.tpl"
      vhost_file="/etc/nginx/sites-enabled/$vhost_hostname"

      _log "'$vhost_hostname' vhost"

      # take the "global" PHP_BACKEND
      # if no 'php_backend' is given for the current vhost
      if [ $vhost_php_backend == "null" ]; then
        vhost_php_backend=${PHP_BACKEND:-<null>}
      fi

      # check if the template file exists
      if [ ! -f $tpl_file ]; then
        _warning "template file '$tpl_file' doesn't exists"
      else
        _debug "=> based on template '$tpl_file'"
        # if no 'vhost_root' is defined set a default
        # location based on 'customer' and "vhost_hostname"
        if [ $vhost_root == "null" ]; then
          vhost_root="/home/"$customer"/data/www/"$vhost_hostname"/drupal"
        fi
        # write the vhost configuration
        cp $tpl_file /etc/nginx/sites-enabled/$vhost_hostname
        sed -i \
            -e 's|{{ HOSTNAME }}|'$vhost_hostname'|g' \
            -e 's|{{ ROOT }}|'$vhost_root'|g' \
            -e 's|{{ CUSTOMER }}|'$customer'|g' \
            -e 's|{{ PHP_BACKEND }}|'$vhost_php_backend'|g' \
            $vhost_file
        _debug "=> '$vhost_file' has been written"
      fi

      let vhost_index+=1
    done
  fi
}

activate_service(){
  # """
  # Activate the given service.
  # """
  local service=$1
  local sv_dir="/etc/sv/$service"

  _log "Activating $1 service ..."
  if [ ! -h /etc/service/$service ]; then
    ln -s $sv_dir /etc/service
  fi
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
  configure_nginx_vhost $1
  configure_runit $1
  activate_service "nginx"
  start_runit
}


main $@
