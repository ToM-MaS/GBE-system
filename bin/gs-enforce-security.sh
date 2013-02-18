#!/bin/bash
#
# Gemeinschaft 5
# Enforce file permissions and security settings
#
# Copyright (c) 2013, Julian Pawlowski <jp@jps-networks.eu>
# See LICENSE.GSE file for details.
#

# General settings
[ -e /etc/gemeinschaft/system.conf ] && source /etc/gemeinschaft/system.conf || echo "FATAL ERROR: Local configuration file in /etc/gemeinschaft/system.conf missing"

# General functions
[ -e "${GSE_DIR_NORMALIZED}/lib/gse-functions.sh" ] && source "${GSE_DIR_NORMALIZED}/lib/gse-functions.sh" || exit 1


# check each command return codes for errors
#
set -e

# Enforce root rights
#
if [[ ${EUID} -ne 0 ]];
	then
	echo "ERROR: `basename $0` needs to be run as root. Aborting ..."
	exit 1
fi

# Check for live status
#
[[ x`cat /proc/cmdline | grep boot=live` != x"" ]] && LIVE=true || LIVE=false

# network packet capturing
if [ x"`cat /etc/group | grep ^pcap`" == x"" ]; then
	groupadd -r -f pcap 2>&1 >/dev/null
fi
if [ -e /usr/sbin/tcpdump ]; then
	chgrp -v pcap /usr/sbin/tcpdump
	chmod -v 754 /usr/sbin/tcpdump
	[ "${LIVE}" == "false" ] && setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump
	ln -sf /usr/sbin/tcpdump /usr/local/bin/tcpdump
fi
if [ -e /usr/sbin/ssldump ]; then
	chgrp -v pcap /usr/sbin/ssldump
	chmod -v 754 /usr/sbin/ssldump
	setcap cap_net_raw,cap_net_admin=eip /usr/sbin/ssldump
	ln -sf /usr/sbin/ssldump /usr/local/bin/ssldump
fi
if [ -e /usr/sbin/pcapsipdump ]; then
	chgrp -v pcap /usr/sbin/pcapsipdump
	chmod -v 754 /usr/sbin/pcapsipdump
	[ "${LIVE}" == "false" ] && setcap cap_net_raw,cap_net_admin=eip /usr/sbin/pcapsipdump
	ln -sf /usr/sbin/pcapsipdump /usr/local/bin/pcapsipdump
fi
if [ -e /usr/sbin/iftop ]; then
	chgrp -v pcap /usr/sbin/iftop
	chmod -v 754 /usr/sbin/iftop
	[ "${LIVE}" == "false" ] && setcap cap_net_raw,cap_net_admin=eip /usr/sbin/iftop
	ln -sf /usr/sbin/iftop /usr/local/bin/iftop
fi
if [ -e /usr/sbin/iotop ]; then
	chgrp -v pcap /usr/sbin/iotop
	chmod -v 754 /usr/sbin/iotop
	[ "${LIVE}" == "false" ] && setcap cap_net_admin=eip /usr/sbin/iotop
	ln -sf /usr/sbin/iotop /usr/local/bin/iotop
fi
if [ -e /usr/bin/dumpcap ]; then
	chgrp -v pcap /usr/bin/dumpcap
	chmod -v 754 /usr/bin/dumpcap
	[ "${LIVE}" == "false" ] && setcap cap_net_raw,cap_net_admin+eip /usr/bin/dumpcap
fi
if [ -e /usr/bin/ngrep ]; then
	chgrp -v pcap /usr/bin/ngrep
	chmod -v 754 /usr/bin/ngrep
	[ "${LIVE}" == "false" ] && setcap cap_net_raw,cap_net_admin+eip /usr/bin/ngrep
fi

# Group memberships for GSE_USER
if id -u ${GSE_USER} >/dev/null 2>&1; then
	usermod -g ${GSE_GROUP} ${GSE_USER} 2>&1 >/dev/null
	usermod -a -G freeswitch ${GSE_USER} 2>&1 >/dev/null
	usermod -a -G mon_ami ${GSE_USER} 2>&1 >/dev/null
	usermod -a -G backup ${GSE_USER} 2>&1 >/dev/null
fi

# Group memberships for user gsmaster
if id -u gsmaster >/dev/null 2>&1; then
	usermod -g ${GSE_GROUP} gsmaster 2>&1 >/dev/null
	usermod -a -G freeswitch gsmaster 2>&1 >/dev/null
	usermod -a -G mon_ami gsmaster 2>&1 >/dev/null
	usermod -a -G adm gsmaster 2>&1 >/dev/null
	usermod -a -G staff gsmaster 2>&1 >/dev/null
	usermod -a -G backup gsmaster 2>&1 >/dev/null
	usermod -a -G pcap gsmaster 2>&1 >/dev/null

	if [ x"`cat /etc/group | grep ^gsmaster`" != x"" ]; then
		groupdel gsmaster 2>&1 >/dev/null
	fi
fi

# Group memberships for user www-data
if id -u www-data >/dev/null 2>&1; then
	if [ x"`cat /etc/group | grep ^winbindd_priv`" != x"" ]; then
		usermod -a -G winbindd_priv www-data 2>&1 >/dev/null
	fi
fi

# GS program files
[ ! -d "${GS_DIR}" ] && mkdir -p "${GS_DIR}"
chown -vR "${GSE_USER}"."${GSE_GROUP}" "${GS_DIR}"

# FreeSwitch configurations
[ ! -d  "${GS_DIR_LOCAL}/freeswitch/conf" ] && mkdir -p "${GS_DIR_LOCAL}/freeswitch/conf"
ln -sf `basename "${GS_DIR_LOCAL}"` "${GS_DIR_NORMALIZED_LOCAL}"
chown -vR ${GSE_USER}.freeswitch "${GS_DIR_LOCAL}/freeswitch/conf"
chmod -v 0770 "${GS_DIR_LOCAL}/freeswitch/conf"
chmod -v g+s "${GS_DIR_LOCAL}/freeswitch/conf"
if [ -e /var/lib/freeswitch/.odbc.ini ]; then
	chown -v freeswitch.freeswitch /var/lib/freeswitch/.odbc.ini
	chmod -v 0640 /var/lib/freeswitch/.odbc.ini
fi
[ -e "${GS_DIR_LOCAL}/freeswitch/conf/freeswitch.serial" ] && chmod -v 0640 "${GS_DIR_LOCAL}/freeswitch/conf/freeswitch.serial"
[ -d /etc/freeswitch ] && rm -rf /etc/freeswitch
ln -sf "${GS_DIR_NORMALIZED_LOCAL}/freeswitch/conf" /etc/freeswitch
[ -d /usr/share/freeswitch/scripts ] && rm -rf /usr/share/freeswitch/scripts
ln -sf "${GS_DIR_NORMALIZED}/misc/freeswitch/scripts" /usr/share/freeswitch/scripts

# GS firewall settings
[ ! -d  "${GS_DIR_LOCAL}/firewall" ] && mkdir -p "${GS_DIR_LOCAL}/firewall"
chown -vR ${GSE_USER}.freeswitch "${GS_DIR_LOCAL}/firewall"
chmod -v 0770 "${GS_DIR_LOCAL}/firewall"
chmod -v g+s "${GS_DIR_LOCAL}/firewall"

# GS backup files
GS_BACKUP_DIR="/var/backups/`basename ${GS_DIR}`"
[ ! -d  "${GS_BACKUP_DIR}" ] && mkdir -p "${GS_BACKUP_DIR}"
chown -vR "${GSE_USER}"."${GSE_GROUP}" "${GS_BACKUP_DIR}"
chmod -v 0770 "${GS_BACKUP_DIR}"
chmod -v g+s "${GS_BACKUP_DIR}"

# GS fax files
[ ! -d  "${GS_DIR_LOCAL}/fax/in" ] && mkdir -p "${GS_DIR_LOCAL}/fax/in"
[ ! -d  "${GS_DIR_LOCAL}/fax/out" ] && mkdir -p "${GS_DIR_LOCAL}/fax/out"
chown -vR ${GSE_USER}.freeswitch "${GS_DIR_LOCAL}/fax"
chmod -vR 0770 "${GS_DIR_LOCAL}/fax"
chmod -vR g+s "${GS_DIR_LOCAL}/fax"

# FreeSwitch variable files
[ ! -d  "${GS_DIR_LOCAL}/freeswitch/db" ] && mkdir -p "${GS_DIR_LOCAL}/freeswitch/db"
[ ! -d  "${GS_DIR_LOCAL}/freeswitch/recordings" ] && mkdir -p "${GS_DIR_LOCAL}/freeswitch/recordings"
[ ! -d  "${GS_DIR_LOCAL}/freeswitch/voicemail" ] && mkdir -p "${GS_DIR_LOCAL}/freeswitch/voicemail"
[ ! -d  "${GS_DIR_LOCAL}/freeswitch/storage" ] && mkdir -p "${GS_DIR_LOCAL}/freeswitch/storage"
chown -vR freeswitch.freeswitch "${GS_DIR_LOCAL}/freeswitch/db" "${GS_DIR_LOCAL}/freeswitch/recordings" "${GS_DIR_LOCAL}/freeswitch/voicemail" "${GS_DIR_LOCAL}/freeswitch/storage"
chmod -v 0770 "${GS_DIR_LOCAL}/freeswitch/db" "${GS_DIR_LOCAL}/freeswitch/recordings" "${GS_DIR_LOCAL}/freeswitch/voicemail" "${GS_DIR_LOCAL}/freeswitch/storage"

# FreeSwitch files
[ ! -d  /usr/share/freeswitch/sounds ] && mkdir -p /usr/share/freeswitch/sounds
chown -v ${GSE_USER}.root /usr/share/freeswitch/sounds
find /usr/share/freeswitch/sounds -type d -exec chmod -v 0775 {} \;
find /usr/share/freeswitch/sounds -type f -exec chmod -v 0664 {} \;

# GSE_USER homedir
[ ! -d  "/var/lib/${GSE_USER}" ] && mkdir -p "/var/lib/${GSE_USER}"
chown -vR ${GSE_USER}.${GSE_GROUP} "/var/lib/${GSE_USER}"
chmod -v 0770 /var/lib/${GSE_USER}
[ -e "${GS_MYSQL_PASSWORD_FILE}" ] && chmod -v 0440 "${GS_MYSQL_PASSWORD_FILE}"

# Logfiles
[ ! -d  /var/log/gemeinschaft ] && mkdir -p /var/log/gemeinschaft
[ ! -d  /var/log/mon_ami ] && mkdir -p /var/log/mon_ami
chown -vR "${GSE_USER}"."${GSE_GROUP}" /var/log/gemeinschaft
chown -vR mon_ami.mon_ami /var/log/mon_ami
chmod -v 0770 /var/log/gemeinschaft
chmod -v 0770 /var/log/mon_ami

# Spooling directories
[ ! -d  /var/spool/freeswitch ] && mkdir -p /var/spool/freeswitch
chown -vR freeswitch.root /var/spool/freeswitch

# Setup some system commands via sudo
[ ! -d  /etc/sudoers.d ] && mkdir -p /etc/sudoers.d
echo "Cmnd_Alias UPDATE = /usr/bin/gs-update --force-update-init" > /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias UPDATE_CANCEL = /usr/bin/gs-update --cancel" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias SHUTDOWN = /sbin/shutdown -h now" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias REBOOT = /sbin/shutdown -r now" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias FW = /usr/sbin/service shorewall refresh" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias FW6 = /usr/sbin/service shorewall6 refresh" >> /etc/sudoers.d/gemeinschaft

# Allow GS service account some system commands via sudo
echo "${GSE_USER} ALL = (ALL) NOPASSWD: UPDATE, UPDATE_CANCEL, SHUTDOWN, REBOOT, FW, FW6" >> /etc/sudoers.d/gemeinschaft

# Allow FreeSwitch some system commands via sudo
echo "freeswitch ALL = (ALL) NOPASSWD: FW, FW6" >> /etc/sudoers.d/gemeinschaft

chown -v root.root /etc/sudoers.d/*
chmod -v 0440 /etc/sudoers.d/*
