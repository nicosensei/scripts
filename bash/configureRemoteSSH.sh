#! /bin/bash

ID_RSA=/home/ngiraud/.ssh/id_rsa.pub
REMOTE_USER=dlweb
WIPE_AUTHORIZED_KEYS=true
WIPE_KNOWN_HOSTS=true

for h in "$@"; do
    TMP_FILE="/home/$REMOTE_USER/.ssh/`date +%s`.pub"
    scp $ID_RSA $REMOTE_USER@$h:$TMP_FILE
    CMD=""
    case $WIPE_AUTHORIZED_KEYS in
        (true)    CMD="$CMD rm -vf /home/$REMOTE_USER/.ssh/authorized_keys ;";;
    esac
    case $WIPE_KNOWN_HOSTS in
        (true)    CMD="$CMD rm -vf /home/$REMOTE_USER/.ssh/known_hosts ;";;
    esac
    CMD="$CMD cat $TMP_FILE >> /home/$REMOTE_USER/.ssh/authorized_keys ;"
    CMD="$CMD chmod 600 /home/$REMOTE_USER/.ssh/authorized_keys ; rm $TMP_FILE"
    ssh $REMOTE_USER@$h "$CMD"
done
