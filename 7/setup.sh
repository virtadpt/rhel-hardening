#!/bin/bash

# by: drwho at virtadpt dot net

# Copies all this stuff into place on a brand-new system to harden it.  Also
# installs some useful packages for monitoring.

# You must be this high <hand> to ride this ride.
if [ `id -u` -gt 0 ]; then
    echo "You must be root to update the $NAME codebase. ABENDing."
    exit 1
fi

# Patch the system.
yum update -y

# /tmp directories - there can be only one.
rmdir /var/tmp
ln -s /tmp /var/tmp

# Postfix sends mail.
# AIDE monitors the file system.
# Logwatch parses the logfiles and mails you about anomalies.
apt-get install -y logwatch

# These are always good to have around.
yum install -y haveged ntp lynx sslscan psmisc sysstat audit postfix aide

# Install all the files.  All of them.
cp -rv * /etc

# Fix file permissions.
chmod 0600 /etc/aide.conf

# Just not this one.
rm -f /etc/setup.sh

# We have to explicitly start and enable new services.
systemctl start haveeged
systemctl enable haveeged
systemctl start ntpd
systemctl enable ntpd
systemctl start auditd 
systemctl enable auditd

# Stop and disable a bunch of services.

# Build the initial AIDE database.
echo "Building initial AIDE database.  Please be patient, this takes a while."
aide.wrapper --init
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Fin.
exit 0
