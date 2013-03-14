#!/usr/bin/env bash
#
# email.sh - email accounts yo
#

email() {
  
  # environmental safety
  ( __email_main "$@" )
}

__email_main() {
  
  # cd to own dir
  cd "$(dirname "$BASH_SOURCE")"
  
  # dependencies
  source argue/0.0.1/lib/argue.sh || return 1
  
  # parse args
  args=("$@")
  argue "-u, --user, +" || return 1
  
  # vars
  cmd="${args[0]}"
  user="${args[1]}"
  pass="${args[2]}"
  
  # sanity checks
  [ "$(whoami)" != "root" ] && echo "you must be root (sudo)" >&2 && return 1
  [ -z "$cmd" ] && echo "please specify a command" >&2 && return 1  
  
  # switch commands
  case "$cmd" in
    "add") __email_add "$@";;
    "edit") __email_edit "$@";;
    "remove") __email_remove "$@";;
    *)
      echo "$cmd: command not found" >&2 && return 127
      ;;
  esac
}

__email_add() {
  
  # sanity
  [ -z "$user" ] && echo "error: please specify a user" >&2 && return 1
  [ -z "$pass" ] && echo "error: please specify a password" >&2 && return 1
  [ -n "$(grep "^$user:" /etc/passwd)" ] && echo "error: $user exists" >&2 && return 1
  
  #
  
  
  # create user
  groupadd "$user"
  useradd -g"$user" -s/bin/bash -d/home/"$user" -m "$user"
  useradd "$user" -p "$(mkpasswd "$pass")"
  mkdir -p /home/"$user"/Maildir/cur
}

__email_edit() {

  # sanity
  [ -z "$user" ] && echo "error: please specify a user" >&2 && return 1
  [ -z "$pass" ] && echo "error: please specify a password" >&2 && return 1
  [ -z "$(grep "^$user:" /etc/passwd)" ] && echo "error: $user does not exist" >&2 && return 1
  
  useradd "$user" -p "$(mkpasswd "$pass")"
}

__email_remove() {
  
  # sanity
  [ -z "$user" ] && echo "error: please specify a user" >&2 && return 1
  [ -z "$(grep "^$user:" /etc/passwd)" ] && echo "error: $user does not exist" >&2 && return 1
  
  deluser "$user"
  delgroup "$user"
  rm -rf /home/"$user"
}

__email_init() {
  
  # sanity
  [ -d /etc/postfix ] && echo "error: postfix is already installed" >&2 && return 1

  # 
  DEBIAN_FRONTEND=noninteractive apt-get install postfix -y
  DEBIAN_FRONTEND=noninteractive apt-get install courier-pop -y
  postconf -e "home_mailbox = Maildir/"
  postconf -e "mailbox_command = "
}

__email_domain() {
  
  # 
  action="$3"
  domain="$4"
  
  # sanity
  
  
  #
  case "$action" in
    "add")
      postconf -e "$(postconf mydestination), $domain"
      ;;
    "remove")
      postconf -e "$(postconf mydestination | sed "s/\(.*\)$domain\(.*\)//")"
      ;;
    *)
      echo "$action: command not found" >&2 && return 127
      ;;
  esac
}
