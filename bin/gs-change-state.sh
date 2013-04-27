#!/bin/bash
#
# Gemeinschaft 5
# Change between production and development state
#
# Copyright (c) 2012-2013, Julian Pawlowski <jp@jps-networks.eu>
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

case "${GSE_ENV}" in

	# Lower debug levels for productive installations
	production)
		if [ ! -L /etc/apache2/sites-enabled/gemeinschaft ]; then
			echo "** Updating Apache configuration to production level"
			a2ensite gemeinschaft
		fi
		[ -L /etc/apache2/sites-enabled/gemeinschaft-development ] && a2dissite gemeinschaft-development
		;;

	# Higher debug levels for development installations
	development)
		if [ ! -L /etc/apache2/sites-enabled/gemeinschaft-development ]; then
			echo "** Updating Apache configuration to development level"
			a2ensite gemeinschaft-development
		fi
		[ -L /etc/apache2/sites-enabled/gemeinschaft ] && a2dissite gemeinschaft
		;;
	*)
		echo "Incorrect setting for GSE_ENV in /etc/gemeinschaft/system.conf"
		exit 3
		;;
esac
