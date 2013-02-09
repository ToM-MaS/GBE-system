#!/bin/bash
#
# Gemeinschaft 5
# Debugging helper
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


# Run switcher
#
echo -e "***    ------------------------------------------------------------------
***     GEMEINSCHAFT DEBUGGING HELPER v${GSE_VERSION}
***     Base System Build: #${GS_BUILDNAME}
***    ------------------------------------------------------------------"

GS_DEBUG_ACTION="$1"

case "${GS_DEBUG_ACTION}" in
	livedump-full)
		echo -e "\nReal-time traffic dump (full packets) on SIP port 5060\n"
		tcpdump -nq -s 0 -A -vvv port 5060
		;;

	livedump)
		if [ ! -e /usr/bin/tshark ]; then
			echo "Please install tshark first, e.g. by installing GS Add-On 'advanced-debug'."
			exit 1
		fi

		echo -e "\nReal-time cleartext traffic dump on SIP port 5060\n"
		tshark -R "sip"
		;;

	help|-h|--help|*)
		echo -e "\nUsage: `basename $0` [  ]\n"
		exit 1
		;;
esac

exit 0
