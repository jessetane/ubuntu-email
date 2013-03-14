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
  domain="$(echo "$user" | sed "s/.*@\(.*\)/\1/" )"
  
  # sanity checks
  [ -z "$cmd" ] && echo "please specify a command" >&2 && return 1  
  [ -z "$domain" ] && echo "$user does not appear to be an email address" >&2 && return 1
  
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
  
  # be sure postfix and courier-pop are installed and configured
  __email_ensure_postfix
  
  # start postfix if not running
  ps aux | grep postfix | grep -v grep > /dev/null || sudo postfix start
  
  # create user
  sudo groupadd "$user"
  sudo useradd -g"$user" -s/bin/bash -d/home/"$user" -m "$user"
  sudo su "$user" -c 'mkdir -p /home/'"$user"'/Maildir/cur'
  echo "$user":"$pass" | sudo chpasswd
  
  # postfix virtual mapping for user
  echo "$user $user" | sudo tee -a /etc/postfix/virtual
  sudo postmap /etc/postfix/virtual
  
  # ensure postfix knows to accept mail for domain
  __email_add_domain "$domain"
  
  # reload
  __email_reload
}

__email_edit() {

  # sanity
  [ -z "$user" ] && echo "error: please specify a user" >&2 && return 1
  [ -z "$pass" ] && echo "error: please specify a password" >&2 && return 1
  [ -z "$(grep "^$user:" /etc/passwd)" ] && echo "error: $user does not exist" >&2 && return 1
  
  echo "$user":"$pass" | sudo chpasswd
}

__email_remove() {
  
  # sanity
  [ -z "$user" ] && echo "error: please specify a user" >&2 && return 1
  [ -z "$(grep "^$user:" /etc/passwd)" ] && echo "error: $user does not exist" >&2 && return 1
  
  sudo deluser "$user"
  sudo delgroup "$user"
  sudo rm -rf /home/"$user"
  
  # remove virtual mapping
  line="$(grep -n "$user" /etc/postfix/virtual | sed "s/\(.*\):.*/\1/")"
  [ -n "$line" ] && sudo sed -i "${line}d;" /etc/postfix/virtual
  sudo postmap /etc/postfix/virtual
  
  # possibly stop listening for mail to domain if no accounts are registered
  __email_remove_domain "$domain"
  
  # reload
  __email_reload
}

__email_ensure_postfix() {
  dpkg -l postfix > /dev/null 2>&1 || sudo DEBIAN_FRONTEND=noninteractive apt-get install postfix -y
  dpkg -l courier-pop > /dev/null 2>&1 || sudo DEBIAN_FRONTEND=noninteractive apt-get install courier-pop -y
  sudo postconf -e "home_mailbox = Maildir/"
  sudo postconf -e "mailbox_command = "
  sudo postconf -e "virtual_alias_maps = hash:/etc/postfix/virtual"
  [ ! -f /etc/postfix/virtual ] && sudo touch /etc/postfix/virtual
}

__email_add_domain() {
  postconf mydestination | grep "$domain" > /dev/null || sudo postconf -e "$(postconf mydestination), $domain"
  
  # do we need this?
  #postconf virtual_alias_domains | grep "$domain" > /dev/null || sudo postconf -e "$(postconf virtual_alias_domains), $domain"
  #"virtual_alias_domains = fossedu.org linuxelabs.com"
}

__email_remove_domain() {
  grep "$domain" /etc/passwd > /dev/null || sudo postconf -e "$(postconf mydestination | sed "s/\(.*\), $domain\(.*\)//")"
}

__email_reload() {
  sudo /etc/init.d/postfix restart
}
