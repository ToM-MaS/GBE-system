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

# Check for chroot status
#
[ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ] && CHROOTED=true || CHROOTED=false

# Check platform
#
if [ -e "/etc/rpi-issue" ]; then
	PLATFORM="rpi"
else
	PLATFORM="x86"
fi

# network packet capturing
if [ x"`cat /etc/group | grep ^pcap`" == x"" ]; then
	groupadd -r -f pcap 2>&1 >/dev/null
fi
if [ -e /usr/sbin/tcpdump ]; then
	chgrp -v pcap /usr/sbin/tcpdump
	chmod -v 754 /usr/sbin/tcpdump
	[[ "${LIVE}" == "false" && "${CHROOTED}" == "false" ]] && setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump
	ln -sf /usr/sbin/tcpdump /usr/local/bin/tcpdump
fi
if [ -e /usr/sbin/ssldump ]; then
	chgrp -v pcap /usr/sbin/ssldump
	chmod -v 754 /usr/sbin/ssldump
	[[ "${LIVE}" == "false" && "${CHROOTED}" == "false" ]] && setcap cap_net_raw,cap_net_admin=eip /usr/sbin/ssldump
	ln -sf /usr/sbin/ssldump /usr/local/bin/ssldump
fi
if [ -e /usr/sbin/pcapsipdump ]; then
	chgrp -v pcap /usr/sbin/pcapsipdump
	chmod -v 754 /usr/sbin/pcapsipdump
	[[ "${LIVE}" == "false" && "${CHROOTED}" == "false" ]] && setcap cap_net_raw,cap_net_admin=eip /usr/sbin/pcapsipdump
	ln -sf /usr/sbin/pcapsipdump /usr/local/bin/pcapsipdump
fi
if [ -e /usr/sbin/iftop ]; then
	chgrp -v pcap /usr/sbin/iftop
	chmod -v 754 /usr/sbin/iftop
	[[ "${LIVE}" == "false" && "${CHROOTED}" == "false" ]] && setcap cap_net_raw,cap_net_admin=eip /usr/sbin/iftop
	ln -sf /usr/sbin/iftop /usr/local/bin/iftop
fi
if [ -e /usr/sbin/iotop ]; then
	chgrp -v pcap /usr/sbin/iotop
	chmod -v 754 /usr/sbin/iotop
	[[ "${LIVE}" == "false" && "${CHROOTED}" == "false" ]] && setcap cap_net_admin=eip /usr/sbin/iotop
	ln -sf /usr/sbin/iotop /usr/local/bin/iotop
fi
if [ -e /usr/bin/dumpcap ]; then
	chgrp -v pcap /usr/bin/dumpcap
	chmod -v 754 /usr/bin/dumpcap
	[[ "${LIVE}" == "false" && "${CHROOTED}" == "false" ]] && setcap cap_net_raw,cap_net_admin+eip /usr/bin/dumpcap
fi
if [ -e /usr/bin/ngrep ]; then
	chgrp -v pcap /usr/bin/ngrep
	chmod -v 754 /usr/bin/ngrep
	[[ "${LIVE}" == "false" && "${CHROOTED}" == "false" ]] && setcap cap_net_raw,cap_net_admin+eip /usr/bin/ngrep
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
	usermod -a -G sudo gsmaster 2>&1 >/dev/null
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
chown -vR freeswitch.freeswitch "${GS_DIR_LOCAL}/freeswitch/conf"
chmod -v 0770 "${GS_DIR_LOCAL}/freeswitch/conf"
chmod -v g+s "${GS_DIR_LOCAL}/freeswitch/conf"
if [ -e /var/lib/freeswitch/.odbc.ini ]; then
	chown -v freeswitch.freeswitch /var/lib/freeswitch/.odbc.ini
	chmod -v 0640 /var/lib/freeswitch/.odbc.ini
fi
[ -d /etc/freeswitch ] && rm -rf /etc/freeswitch
ln -sf "${GS_DIR_NORMALIZED_LOCAL}/freeswitch/conf" /etc/freeswitch
[ -d /usr/share/freeswitch/scripts ] && rm -rf /usr/share/freeswitch/scripts
ln -sf "${GS_DIR_NORMALIZED}/misc/freeswitch/scripts" /usr/share/freeswitch/scripts

# GS firewall settings
[ ! -d  "${GS_DIR_LOCAL}/firewall" ] && mkdir -p "${GS_DIR_LOCAL}/firewall"
chown -vR freeswitch.freeswitch "${GS_DIR_LOCAL}/firewall"
chmod -v 0770 "${GS_DIR_LOCAL}/firewall"
chmod -v g+s "${GS_DIR_LOCAL}/firewall"
find "${GS_DIR_LOCAL}/firewall/" -type f -exec chmod -v 660 {} \;

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
chmod -v 0770 "${GS_DIR_LOCAL}/fax" "${GS_DIR_LOCAL}/fax/in" "${GS_DIR_LOCAL}/fax/out"
chmod -v g+s "${GS_DIR_LOCAL}/fax" "${GS_DIR_LOCAL}/fax/in" "${GS_DIR_LOCAL}/fax/out"

# GS generic media archive files
GS_MEDIA_FILES="${GS_DIR_LOCAL}/generic_files"
[ ! -d  "${GS_MEDIA_FILES}" ] && mkdir -p "${GS_MEDIA_FILES}"
chown -vR "${GSE_USER}".freeswitch "${GS_MEDIA_FILES}"
chmod -v 0770 "${GS_MEDIA_FILES}"
chmod -v g+s "${GS_MEDIA_FILES}"

# FreeSwitch variable files
[ ! -d  "${GS_DIR_LOCAL}/freeswitch/db" ] && mkdir -p "${GS_DIR_LOCAL}/freeswitch/db"
[ ! -d  "${GS_DIR_LOCAL}/freeswitch/recordings" ] && mkdir -p "${GS_DIR_LOCAL}/freeswitch/recordings"
[ ! -d  "${GS_DIR_LOCAL}/freeswitch/voicemail" ] && mkdir -p "${GS_DIR_LOCAL}/freeswitch/voicemail"
[ ! -d  "${GS_DIR_LOCAL}/freeswitch/storage" ] && mkdir -p "${GS_DIR_LOCAL}/freeswitch/storage"
chown -vR freeswitch.freeswitch "${GS_DIR_LOCAL}/freeswitch/db" "${GS_DIR_LOCAL}/freeswitch/recordings" "${GS_DIR_LOCAL}/freeswitch/voicemail" "${GS_DIR_LOCAL}/freeswitch/storage"
chmod -v 0770 "${GS_DIR_LOCAL}/freeswitch/db" "${GS_DIR_LOCAL}/freeswitch/recordings" "${GS_DIR_LOCAL}/freeswitch/voicemail" "${GS_DIR_LOCAL}/freeswitch/storage"

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
chown -vR freeswitch.${GSE_GROUP} /var/spool/freeswitch
chmod -v 0770 /var/spool/freeswitch
chmod -v g+ws /var/spool/freeswitch
[ ! -d  /var/spool/gemeinschaft ] && mkdir -p /var/spool/gemeinschaft
chown -vR ${GSE_USER}.${GSE_GROUP} /var/spool/gemeinschaft
chmod -v 0770 /var/spool/gemeinschaft
chmod -v g+ws /var/spool/gemeinschaft

# Platform specific link for libs
if [ "${PLATFORM}" == "rpi" ]; then
	ln -sf arm-linux-gnueabihf /usr/lib/local-platform
	ln -sf arm-linux-gnueabihf /lib/local-platform
else
	ln -sf i386-linux-gnu /usr/lib/local-platform
	ln -sf i386-linux-gnu /lib/local-platform
fi


# Setup some system commands via sudo
[ ! -d  /etc/sudoers.d ] && mkdir -p /etc/sudoers.d
echo "Cmnd_Alias UPDATE = /usr/bin/gs-update --force-update-init" > /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias UPDATE_CANCEL = /usr/bin/gs-update --cancel" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias SHUTDOWN = /sbin/shutdown -h now" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias REBOOT = /sbin/shutdown -r now" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias FW = /usr/sbin/service shorewall refresh" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias FW6 = /usr/sbin/service shorewall6 refresh" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias APACHE_STOP = /usr/sbin/service apache2 stop" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias APACHE_START = /usr/sbin/service apache2 start" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias APACHE_RESTART = /usr/sbin/service apache2 restart" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias APACHE_RELOAD = /usr/sbin/service apache2 reload" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias FS_STOP = /usr/sbin/service freeswitch stop" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias FS_START = /usr/sbin/service freeswitch start" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias FS_RESTART = /usr/sbin/service freeswitch restart" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias FS_RELOAD = /usr/sbin/service freeswitch reload" >> /etc/sudoers.d/gemeinschaft
echo "Cmnd_Alias TAR = /bin/tar" >> /etc/sudoers.d/gemeinschaft

# Allow GS service account some system commands via sudo
echo "${GSE_USER} ALL = (ALL) NOPASSWD: UPDATE, UPDATE_CANCEL, SHUTDOWN, REBOOT, FW, FW6, APACHE_STOP, APACHE_START, APACHE_RESTART, APACHE_RELOAD, FS_STOP, FS_START, FS_RESTART, FS_RELOAD, TAR" >> /etc/sudoers.d/gemeinschaft

# Allow FreeSwitch some system commands via sudo
echo "freeswitch ALL = (ALL) NOPASSWD: FW, FW6" >> /etc/sudoers.d/gemeinschaft

chown -v root.root /etc/sudoers.d/gemeinschaft
chmod -v 0440 /etc/sudoers.d/gemeinschaft
