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

# Fix file and directory permissions.
chmod 0600 /etc/aide.conf
chmod 0600 /boot/grub/grub.conf
chmod 0750 /var/log/sudo-io
chmod 0600 /etc/crontab
chmod 0700 /etc/cron.d
chmod 0700 /etc/cron.daily
chmod 0700 /etc/cron.hourly
chmod 0700 /etc/cron.monthly
chmod 0700 /etc/cron.weekly
chmod 0700 /etc/skel/.ssh
chmod 0600 /etc/skel/.ssh/authorized_keys
chmod 0600 /etc/ssh/sshd_config

# Just not this one.
rm -f /etc/setup.sh

# We have to explicitly start and enable new services.
systemctl start haveged
systemctl enable haveged
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
echo "# Audit use of privileged commands." >> \
    /etc/audit/rules.d/privileged.rules
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f | \
    awk '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged"}' >> /etc/audit/rules.d/privileged.rules
echo "" >> /etc/audit/rules.d/privileged.rules

# Make the audit rules configuration immutable.
echo "# Making auditing configuration immutable." >> \
    /etc/audit/rules.d/privileged.rules
echo "-e 2" >> /etc/audit/rules.d/privileged.rules
echo "" >> /etc/audit/rules.d/privileged.rules

# Configure cron's access controls.
rm -f /etc/cron.deny /etc/at.deny
touch /etc/cron.allow /etc/at.allow
chmod 0600 /etc/cron.allow /etc/at.allow

# Generate any SSH hostkeys that don't exist yet.
ssh-keygen -A

# Search for and re-set world-writable files.
echo -n "Searching for and locking down world-writable files..."
for i in `egrep '(ext?|xfs)' /etc/fstab | awk '{print $2}'`; do
    find $i -xdev -type f -perm -0002 -exec chmod o-w {} \;
done
echo " done."

# Search for and claim files that aren't owned by any existing users.
echo -n "Searching for and claiming files that aren't owned by a user..."
for i in `egrep '(ext?|xfs)' /etc/fstab | awk '{print $2}'`; do
    find $i -xdev \( -type f -o -type d \) -nouser -exec chown root {} \;
done
echo " done."

# Search for and claim files that aren't owned by any existing groups.
echo -n "Searching for and claiming files that aren't owned by a group..."
for i in `egrep '(ext?|xfs)' /etc/fstab | awk '{print $2}'`; do
    find $i -xdev \( -type f -o -type d \) -nogroup -exec chown root {} \;
done
echo " done."

# Build the initial AIDE database.
echo "Building initial AIDE database.  Please be patient, this takes a while."
/usr/sbin/aide --init
cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# Fin.
exit 0
