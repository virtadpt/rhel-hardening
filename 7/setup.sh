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

# Create a directory for sudo to log to.
mkdir -p /var/log/sudo-io

# Install some basic packages that might not be in the default install.
yum install -y haveged ntp lynx sslscan psmisc sysstat audit postfix aide
yum install -y logwatch rsyslog tcp_wrappers

# Install all the files.  All of them.
cp -rv * /etc

# Fix file permissions.
chmod 0600 /etc/aide.conf
chmod 0600 /boot/grub/grub.conf
chmod 0750 /var/log/sudo-io

# Just not this one.
rm -f /etc/setup.sh

# We have to explicitly start and enable new services.
systemctl start haveeged
systemctl enable haveeged
systemctl start ntpd
systemctl enable ntpd
systemctl start auditd 
systemctl enable auditd
systemctl start rsyslog
systemctl enable rsyslog
systemctl start iptables
systemctl enable iptables
systemctl start ip6tables
systemctl enable ip6tables
systemctl start auditd
systemctl enable auditd

# Stop and disable services.
systemctl mask NetworkManager
systemctl stop NetworkManager
systemctl disable NetworkManager

# Remove packages that aren't needed.  Most of these probably aren't installed
# anyway but there's no way of knowing these days.
yum erase -y setroubleshoot mcstrans telnet-server telnet rsh-server rsh
yum erase -y ypbind ypserv tftp-server tftp talk-server talk xinetd

# Ensure that the default runlevel is not "X desktop".
systemctl set-default multi-user.target

# Generate audit rules for every setuid and setgid executable on the system.
# It's easiest to do it now rather than trying to second guess it in a static
# audit.rules file.
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f | \
    awk '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged"}' >> /etc/audit/audit.rules
echo "" >> /etc/audit/audit.rules

# Build the initial AIDE database.
echo "Building initial AIDE database.  Please be patient, this takes a while."
aide --init
cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# Fin.
exit 0
