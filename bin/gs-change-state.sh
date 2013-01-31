#!/bin/bash
#
# Gemeinschaft 5
# Change between production and development state
#
# Copyright (c) 2012-2013, Julian Pawlowski <jp@jps-networks.eu>
# See LICENSE.GSE file for details.
#

# General settings
[ -f /etc/gemeinschaft/system.conf ] && source /etc/gemeinschaft/system.conf || echo "FATAL ERROR: Local configuration file in /etc/gemeinschaft/system.conf missing"

# General functions
[ -f "${GSE_DIR_NORMALIZED}/lib/gse-functions.sh" ] && source "${GSE_DIR_NORMALIZED}/lib/gse-functions.sh" || exit 1


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

case "${GSE_ENV}" in

	# Lower debug levels for productive installations
	production)
		if [ -f "${GS_DIR_NORMALIZED_LOCAL}/freeswitch/conf/freeswitch.xml" ]; then
			echo "** Updating FreeSwitch debugging to production level"
			sed -i "s/<map name=\"all\" value=\"debug,info,notice,warning,err,crit,alert\"\/>/<map name=\"all\" value=\"info,notice,warning,err,crit,alert\"\/>/" "${GS_DIR_NORMALIZED_LOCAL}/freeswitch/conf/freeswitch.xml"
		fi

		if [ -f "/etc/apache2/sites-available/gemeinschaft" ]; then
			echo "** Updating Apache Passenger environment to production level"
			sed -i "s/RailsEnv development/RailsEnv production/" "/etc/apache2/sites-available/gemeinschaft"
		fi

		;;

	# Higher debug levels for development installations
	development)
		if [ -f "${GS_DIR_NORMALIZED_LOCAL}/freeswitch/conf/freeswitch.xml" ]; then
			echo "** Updating FreeSwitch debugging to development level"
			sed -i "s/<map name=\"all\" value=\"info,notice,warning,err,crit,alert\"\/>/<map name=\"all\" value=\"debug,info,notice,warning,err,crit,alert\"\/>/" "${GS_DIR_NORMALIZED_LOCAL}/freeswitch/conf/freeswitch.xml"
		fi

		if [ -f "/etc/apache2/sites-available/gemeinschaft" ]; then
			echo "** Updating Apache Passenger environment to development level"
			sed -i "s/RailsEnv production/RailsEnv development/" "/etc/apache2/sites-available/gemeinschaft"
		fi

		;;
	*)
		echo "Incorrect setting for GSE_ENV in /etc/gemeinschaft/system.conf"
		exit 3
		;;
esac
