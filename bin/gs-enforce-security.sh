#!/bin/bash
#
# Gemeinschaft 5
# Enforce file permissions and security settings
#
# Copyright (c) 2013, Julian Pawlowski <jp@jps-networks.eu>
# See LICENSE.GSE file for details.
#

# General settings
[ -f /etc/gemeinschaft/system.conf ] && source /etc/gemeinschaft/system.conf || echo "FATAL ERROR: Local configuration file in /etc/gemeinschaft/system.conf missing"

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

# Group memberships for GSE_USER
if id -u ${GSE_USER} >/dev/null 2>&1; then
	usermod -g ${GSE_GROUP} ${GSE_USER} 2>&1 >/dev/null
	usermod -a -G freeswitch ${GSE_USER} 2>&1 >/dev/null
	usermod -a -G mon_ami ${GSE_USER} 2>&1 >/dev/null
fi

# Group memberships for user gsmaster
if id -u gsmaster >/dev/null 2>&1; then
	usermod -g ${GSE_GROUP} gsmaster 2>&1 >/dev/null
	usermod -a -G freeswitch gsmaster 2>&1 >/dev/null
	usermod -a -G mon_ami gsmaster 2>&1 >/dev/null

	if [ x"`cat /etc/group | grep ^gsmaster`" != x"" ]; then
		groupdel gsmaster 2>&1 >/dev/null
	fi
fi

# GS program files
[ ! -d "${GS_DIR}" ] && mkdir -p "${GS_DIR}"
chown -vR "${GSE_USER}"."${GSE_GROUP}" "${GS_DIR}"

# FreeSwitch configurations
[ ! -d  "${GS_DIR_LOCAL}/freeswitch/conf" ] && mkdir -p "${GS_DIR_LOCAL}/freeswitch/conf"
chown -vR ${GSE_USER}.freeswitch "${GS_DIR_LOCAL}/freeswitch/conf"
chmod -v 0770 "${GS_DIR_LOCAL}/freeswitch/conf"
if [ -f /var/lib/freeswitch/.odbc.ini ]; then
	chown -v freeswitch.freeswitch /var/lib/freeswitch/.odbc.ini
	chmod -v 0640 /var/lib/freeswitch/.odbc.ini
fi
[ -f "${GS_DIR_LOCAL}/freeswitch/conf/freeswitch.serial" ] && chmod -v 0640 "${GS_DIR_LOCAL}/freeswitch/conf/freeswitch.serial"

# GS firewall settings
[ ! -d  "${GS_DIR_LOCAL}/firewall" ] && mkdir -p "${GS_DIR_LOCAL}/firewall"
chown -vR ${GSE_USER}.${GSE_GROUP} "${GS_DIR_LOCAL}/firewall"
chmod -v 0770 "${GS_DIR_LOCAL}/firewall"

# GS backup files
GS_BACKUP_DIR="/var/backups/`basename ${GS_DIR}`"
[ ! -d  "${GS_BACKUP_DIR}" ] && mkdir -p "/${GS_BACKUP_DIR}"
chown -vR "${GSE_USER}"."${GSE_GROUP}" "${GS_BACKUP_DIR}"
chmod -v 0770 "${GS_BACKUP_DIR}"

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
[ -f "${GS_MYSQL_PASSWORD_FILE}" ] && chmod -v 0440 "${GS_MYSQL_PASSWORD_FILE}"

# Logfiles
[ ! -d  /var/log/gemeinschaft ] && mkdir -p /var/log/gemeinschaft
chown -vR "${GSE_USER}"."${GSE_GROUP}" /var/log/gemeinschaft
chown -vR mon_ami.mon_ami /var/log/mon_ami
chmod -v 0770 /var/log/gemeinschaft
chmod -v 0770 /var/log/mon_ami

# Spooling directories
[ ! -d  /var/spool/freeswitch ] && mkdir -p /var/spool/freeswitch
chown -vR freeswitch.root /var/spool/freeswitch

# Allow GS service account some system commands via sudo
[ ! -d  /etc/sudoers.d ] && mkdir -p /etc/sudoers.d
echo "Cmnd_Alias UPDATE = /usr/bin/gs-update --force-update-init" > /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias UPDATE_CANCEL = /usr/bin/gs-update --cancel" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias SHUTDOWN = /sbin/shutdown -h now" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias REBOOT = /sbin/shutdown -r now" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias FW = /usr/sbin/service shorewall refresh" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias FW6 = /usr/sbin/service shorewall6 refresh" >> /etc/sudoers.d/gemeinschaft
echo "${GSE_USER} ALL = (ALL) NOPASSWD: UPDATE, UPDATE_CANCEL, SHUTDOWN, REBOOT, FW, FW6" >> /etc/sudoers.d/gemeinschaft
chown -v root.root /etc/sudoers.d/*
chmod -v 0440 /etc/sudoers.d/*
