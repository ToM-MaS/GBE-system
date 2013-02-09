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


# Run switcher
#
echo -e "***    ------------------------------------------------------------------
***     GEMEINSCHAFT DEBUGGING HELPER v${GSE_VERSION}
***     Base System Build: #${GS_BUILDNAME}
***    ------------------------------------------------------------------"

GS_DEBUG_ACTION="$1"

case "${GS_DEBUG_ACTION}" in
	livedump-full)
		echo -e "\nReal-time traffic dump (full packets) for SIP\n"
		tcpdump -nq -s 0 -A -vvv port 5060
		;;

	livedump)
		if [ ! -e /usr/bin/tshark ]; then
			echo -e "\nPlease install tshark first, e.g. by installing GS Add-On 'advanced-debug'.\nHowever you may still use '`basename $0` livedump-full' without installing additional packages.\n"
			exit 1
		fi

		if [ x"$2" == x"ip" ]; then
			if [ x"$3" == "" ]; then
				echo -e "\nThird parameter missing: IP address. Aborting ...\n"
				exit 1
			fi
			echo -e "\nReal-time cleartext traffic dump for SIP with partner IP $3\n"
			/usr/bin/tshark -R "sip and ip.addr == $3"
		elif [ x"$2" == x"account" ]; then
			if [ x"$3" == "" ]; then
				echo -e "\nThird parameter missing: SIP account. Aborting ...\n"
				exit 1
			fi
			echo -e "\nReal-time cleartext traffic dump for SIP account $3\n"
			/usr/bin/tshark -R "rtcp.app.poc1.sip.uri contains $3"
		else
			echo -e "\nReal-time cleartext traffic dump for SIP\n"
			/usr/bin/tshark -R "sip"
		fi
		;;

	help|-h|--help|*)
		echo -e "\nUsage: `basename $0` [ livedump | livedump-full ]\n"
		exit 1
		;;
esac

exit 0
