#!/bin/bash
#
# Gemeinschaft 5
# System add-on installer
#
# Copyright (c) 2013, Julian Pawlowski <jp@jps-networks.eu>
# See LICENSE.GBE file for details.
#

# General settings
[ -f /etc/gemeinschaft/system.conf ] && source /etc/gemeinschaft/system.conf || echo "FATAL ERROR: Local configuration file in /etc/gemeinschaft/system.conf missing"

GSE_ADDON_DIR="${GSE_DIR_NORMALIZED}/lib/addons"
GSE_ADDON_STATUSFILE="${GSE_ADDON_STATUSFILE}"

# Enforce root rights
#
if [[ ${EUID} -ne 0 ]];
	then
	echo "ERROR: `basename $0` needs to be run as root. Aborting ..."
	exit 1
fi

# For Debian
if [ -f /etc/debian_version ]; then
	OS_DISTRIBUTION="Debian"
	OS_VERSION="`cat /etc/debian_version`"
	OS_VERSION_MAJOR=${OS_VERSION%%.*}

	if [ x"${OS_VERSION_MAJOR}" == x"6" ]; then
		OS_CODENAME="squeeze"
	elif [ x"${OS_VERSION_MAJOR}" == x"7" ]; then
		OS_CODENAME="wheezy"
	else
		echo "ERROR: ${OS_DISTRIBUTION} version ${OS_VERSION} is not supported. Aborting ..."
		exit 1
	fi
# Unsupported Distribution
else
	echo "ERROR: This Linux distribution is not supported. Aborting ..."
	exit 1
fi


# Run switcher
#
echo -e "***    ------------------------------------------------------------------
***     GEMEINSCHAFT SYSTEM ADD-ON MANAGEMENT v${GSE_VERSION}
***     Base System Build: #${GS_BUILDNAME}
***    ------------------------------------------------------------------"

GSE_ADDON_ACTION="$1"
GSE_ADDON_NAME="$2"

case "${GSE_ADDON_ACTION}" in
	install|remove)
		if [ x"${GSE_ADDON_NAME}" ==  x"" ]; then
			echo -e "\n\nPlease specify an add-on name.\n"
			exit 1
		fi
		if [ -d "${GSE_ADDON_DIR}" ]; then
			
			# Try to find the specified add-on script
			[ -d "${GSE_ADDON_DIR}/${OS_CODENAME}" ] && GSE_ADDON_SCRIPT="`find "${GSE_ADDON_DIR}/${OS_CODENAME}" -maxdepth 1 -type f -name "${GSE_ADDON_NAME}" ! -iname ".*"`" || GSE_ADDON_SCRIPT=""
			[ "${GSE_ADDON_SCRIPT}" == "" ] && GSE_ADDON_SCRIPT="`find "${GSE_ADDON_DIR}" -maxdepth 1 -type f -name "${GSE_ADDON_NAME}" ! -iname ".*"`"

			if [ -f "${GSE_ADDON_SCRIPT}" ]; then

				[ -f "${GSE_ADDON_STATUSFILE}" ] && GSE_ADDON_STATUS="`sed -n "/^${GSE_ADDON_NAME} .*$/p" "${GSE_ADDON_STATUSFILE}"`" || GSE_ADDON_STATUS=""

				# Process installation
				if [ "${GSE_ADDON_ACTION}" == "install" ]; then
					if [ x"${GSE_ADDON_STATUS}" == x"" ]; then
						echo -e "\nStarting installation of add-on '${GSE_ADDON_NAME}' ...\n"
						export OS_DISTRIBUTION
						export OS_VERSION
						export OS_VERSION_MAJOR
						export OS_CODENAME
						bash ${GSE_ADDON_SCRIPT} install
						if [ $? != 0 ]; then
							echo -e "\n\n***    ------------------------------------------------------------------"
							echo -e "***     ERROR: Installation of add-on '${GSE_ADDON_NAME}' FAILED!"
							echo -e "***    ------------------------------------------------------------------\n\n"
							exit 1
						else
							echo -e "\n\n***    ------------------------------------------------------------------"
							echo -e "***     Add-on '${GSE_ADDON_NAME}' was INSTALLED SUCCESSFULLY!"
							echo -e "***    ------------------------------------------------------------------\n\n"
							echo "${GSE_ADDON_NAME} `date +'%Y-%m-%d_%T'`" >> "${GSE_ADDON_STATUSFILE}"
						fi
					else
						echo -e "\n\n***    ------------------------------------------------------------------"
						echo -e "***     Add-on '${GSE_ADDON_NAME}' was already installed on ${GSE_ADDON_STATUS#* }."
						echo -e "***    ------------------------------------------------------------------\n\n"
					fi

				# Process removal
				elif [ "${GSE_ADDON_ACTION}" == "remove" ]; then
					if [ x"${GSE_ADDON_STATUS}" != x"" ]; then
						echo -e "\nRemoving add-on '${GSE_ADDON_NAME}' ...\n"
						export OS_DISTRIBUTION
						export OS_VERSION
						export OS_VERSION_MAJOR
						export OS_CODENAME
						bash ${GSE_ADDON_SCRIPT} remove
						if [ $? != 0 ]; then
							echo -e "\n\n***    ------------------------------------------------------------------"
							echo -e "***     ERROR: Removal of add-on '${GSE_ADDON_NAME}' FAILED!"
							echo -e "***    ------------------------------------------------------------------\n\n"
							exit 1
						else
							echo -e "\n\n***    ------------------------------------------------------------------"
							echo -e "***     Add-on '${GSE_ADDON_NAME}' was REMOVED SUCCESSFULLY!"
							echo -e "***    ------------------------------------------------------------------\n\n"
							sed -i "/^${GSE_ADDON_NAME} .*$/d" "${GSE_ADDON_STATUSFILE}"
						fi
					else
						echo -e "\n\n***    ------------------------------------------------------------------"
						echo -e "***     Add-on '${GSE_ADDON_NAME}' is currently not installed."
						echo -e "***    ------------------------------------------------------------------\n\n"
					fi

				# This should actually not happen
				else
					echo -e "\n\n***    ------------------------------------------------------------------"
					echo -e "***     FATAL ERROR: Logic error."
					echo -e "***    ------------------------------------------------------------------\n\n"
					exit 3
				fi

			# In case we could not find a declared script for the specified add-on
			else
				echo -e "\n\n***    ------------------------------------------------------------------"
				echo -e "***     The specified system add-on '${GSE_ADDON_NAME}'"
				echo -e "***     does not exist or is not available for your system."
				echo -e "***    ------------------------------------------------------------------\n\n"
				exit 1
			fi
		else
			echo -e "\n\n***    ------------------------------------------------------------------"
			echo -e "***     FATAL ERROR: ${GSE_ADDON_DIR} not found."
			echo -e "***    ------------------------------------------------------------------\n\n"
			exit 3
		fi
		;;

	status)
		if [ x"${GSE_ADDON_NAME}" == x"" ]; then
			[ -f "${GSE_ADDON_STATUSFILE}" ] && LIST="`cat "${GSE_ADDON_STATUSFILE}"`" || LIST=""
			[ x"${LIST}" != x"" ] && echo -e "\nThe following add-ons are currently installed:\n${LIST}\n" || echo -e "\nCurrently there are no add-ons installed.\n"
		else
			[ -f "${GSE_ADDON_STATUSFILE}" ] && GSE_ADDON_STATUS="`sed -n "/^${GSE_ADDON_NAME} .*$/p" "${GSE_ADDON_STATUSFILE}"`" || GSE_ADDON_STATUS=""
			[ x"${GSE_ADDON_STATUS}" != x"" ] && echo -e "\nThe system add-on '${GSE_ADDON_NAME}' was installed on ${GSE_ADDON_STATUS#* }.\n" || echo -e "\nThe system add-on '${GSE_ADDON_NAME}' is currently not installed.\n"
		fi
		;;

	list|search)
		[ x"${GSE_ADDON_NAME}" != x"" ] && SEARCHSTRING="*${GSE_ADDON_NAME}*" || SEARCHSTRING="*"

		[ -d "${GSE_ADDON_DIR}/${OS_CODENAME}" ] && LIST="`find "${GSE_ADDON_DIR}/${OS_CODENAME}" -maxdepth 1 -type f -name "${SEARCHSTRING}" ! -iname ".*" | sort`"
		if [ x"${LIST}" != x"" ]; then
			echo -e "\nADD-ONS FOR ${OS_DISTRIBUTION^^} ${OS_CODENAME^^}"
			for GSE_ADDON_SCRIPT in ${LIST}; do
				GSE_ADDON_SCRIPT_BASE="`basename "${GSE_ADDON_SCRIPT}"`"
				[ -f "${GSE_ADDON_STATUSFILE}" ] && GSE_ADDON_STATUS="`sed -n "/^${GSE_ADDON_SCRIPT_BASE} .*$/p" "${GSE_ADDON_STATUSFILE}"`" || GSE_ADDON_STATUS=""
				[ x"${GSE_ADDON_STATUS}" == x"" ] && echo -n "  " || echo -n "* "
				bash "${GSE_ADDON_SCRIPT}" info
			done
		elif [ x"${GSE_ADDON_NAME}" != x"" ]; then
			echo -e "\nADD-ONS FOR ${OS_DISTRIBUTION^^} ${OS_CODENAME^^}"
			echo "  No matching add-ons found."
		fi

		[ -d "${GSE_ADDON_DIR}" ] && LIST="`find "${GSE_ADDON_DIR}" -maxdepth 1 -type f -name "${SEARCHSTRING}" ! -iname ".*" | sort`"
		echo -e "\nGENERAL ADD-ONS"
		if [ x"${LIST}" != x"" ]; then
			for GSE_ADDON_SCRIPT in ${LIST}; do
				GSE_ADDON_SCRIPT_BASE="`basename "${GSE_ADDON_SCRIPT}"`"
				[ -f "${GSE_ADDON_STATUSFILE}" ] && GSE_ADDON_STATUS="`sed -n "/^${GSE_ADDON_SCRIPT_BASE} .*$/p" "${GSE_ADDON_STATUSFILE}"`" || GSE_ADDON_STATUS=""
				[ x"${GSE_ADDON_STATUS}" == x"" ] && echo -n "  " || echo -n "* "
				bash "${GSE_ADDON_SCRIPT}" info
			done
		else
			echo "  No matching add-ons found."
		fi

		echo -e "\n***    ------------------------------------------------------------------"
		echo -e "***     Use '`basename "$0"` install <ADD-ON NAME>' to install."
		echo -e "***     Use '`basename "$0"` remove <ADD-ON NAME>' to uninstall."
		echo -e "***    ------------------------------------------------------------------\n\n"
		;;
	
	help|-h|--help|*)
		echo -e "\nUsage: `basename $0` [ install | remove | list | search | status ] <ADD-ON NAME>\n"
		exit 1
		;;
esac

exit 0
