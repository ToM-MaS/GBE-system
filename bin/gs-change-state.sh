#!/bin/bash
#
# Gemeinschaft 5
# Change between production and development state
#
# Copyright (c) 2012-2013, Julian Pawlowski <jp@jps-networks.eu>
# See LICENSE.GBE file for details.
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

case "${GS_ENV}" in

	# Lower debug levels for productive installations
	production)
		echo "** Updating FreeSwitch debugging to production level"
		sed -i "s/<map name=\"all\" value=\"debug,info,notice,warning,err,crit,alert\"\/>/<map name=\"all\" value=\"info,notice,warning,err,crit,alert\"\/>/" "${GS_DIR_NORMALIZED_LOCAL}/freeswitch/conf/freeswitch.xml"

		echo "** Updating Apache Passenger environment to production level"
		sed -i "s/RailsEnv development/RailsEnv production/" "/etc/apache2/sites-available/gemeinschaft"

		;;

	# Higher debug levels for development installations
	development)
		echo "** Updating FreeSwitch debugging to development level"
		sed -i "s/<map name=\"all\" value=\"info,notice,warning,err,crit,alert\"\/>/<map name=\"all\" value=\"debug,info,notice,warning,err,crit,alert\"\/>/" "${GS_DIR_NORMALIZED_LOCAL}/freeswitch/conf/freeswitch.xml"

		echo "** Updating Apache Passenger environment to development level"
		sed -i "s/RailsEnv production/RailsEnv development/" "/etc/apache2/sites-available/gemeinschaft"

		;;
	*)
		echo "Incorrect setting for GS_ENV in /etc/gemeinschaft/system.conf"
		exit 3
		;;
esac
