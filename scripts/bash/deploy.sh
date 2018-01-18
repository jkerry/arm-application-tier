#!/bin/bash

# Set values for variables
set -e
ATTACH_DISK=$1
MOUNT_POINT=$2
JOIN_DOMAIN=$3
DOMAIN=$4
DOMAIN_USER=$5
DOMAIN_USER_PASS=$6
SUDO_GROUPS=$7
WRITE_VAULT=$8
ROLE_ID=$9
SECRET_ID=${10}

[ -e /cmd.log ] && rm /cmd.log

if [ "$ATTACH_DISK" = 'True' ] ; then
  dev=$(sudo parted -l 2>&1 >/dev/null | grep  "unrecognised disk label" |  sed -En 's/Error: (.*):.*/\1/p')
  echo $dev > /test_dev
  if [ -n "$dev" ]
    then
echo "n
p
1


w
" | fdisk $dev
    mkfs.ext4 -L $MOUNT_POINT "${dev}1"
    mkdir $MOUNT_POINT
    echo "LABEL=$MOUNT_POINT $MOUNT_POINT      ext4    defaults        1 2" >> /etc/fstab
    mount -a
  fi
fi

# Join the given realm if requested. Set the given groups to sudoers
if [ "$JOIN_DOMAIN" = 'True' ] ; then
  # install prerequisite packages to domain join
  yum install sssd realmd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation openldap-clients policycoreutils-python -y

  # Join the domain
  (realm list | grep $DOMAIN) || echo $DOMAIN_USER_PASS | realm join $DOMAIN -U $DOMAIN_USER

  # Allow interaction with AD objects without the domain suffixes
  sed -i '/use_fully_qualified_names = True/c\use_fully_qualified_names = False' /etc/sssd/sssd.conf
  systemctl restart sssd

  export OLDIFS= $IFS
  export IFS=","
  for group in $SUDO_GROUPS; do
    echo "%$group ALL=(ALL)  ALL" >> /etc/sudoers
  done
  export IFS="$OLDIFS"
fi

if [ "$WRITE_VAULT" = 'True' ] ; then
  mkdir -p /etc/chef/hash
  printf '{\n  "role_id": "%s",\n  "secret_id": "%s"\n}' $ROLE_ID $SECRET_ID > /etc/chef/hash/app.json
fi