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
[[ x"${GS_SYSADDON_DIR}" == x"" ]] && exit 1

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
***     GEMEINSCHAFT SYSTEM ADD-ON MANAGEMENT
***     Current version: ${GS_VERSION}
***     Branch: ${GS_BRANCH}
***     Base System Build: ${GS_BUILDNAME}
***    ------------------------------------------------------------------"

GS_SYSADDON_ACTION="$1"
GS_SYSADDON_NAME="$2"

case "${GS_SYSADDON_ACTION}" in
	install|remove)
		if [ x"${GS_SYSADDON_NAME}" ==  x"" ]; then
			echo -e "\n\nPlease specify an add-on name.\n"
			exit 1
		fi
		if [ -d "${GS_SYSADDON_DIR}" ]; then
			
			# Try to find the specified add-on script
			[ -d "${GS_SYSADDON_DIR}/${OS_CODENAME}" ] && GS_SYSADDON_SCRIPT="`find "${GS_SYSADDON_DIR}/${OS_CODENAME}" -maxdepth 1 -type f -name "${GS_SYSADDON_NAME}" ! -iname ".*"`" || GS_SYSADDON_SCRIPT=""
			[ "${GS_SYSADDON_SCRIPT}" == "" ] && GS_SYSADDON_SCRIPT="`find "${GS_SYSADDON_DIR}" -maxdepth 1 -type f -name "${GS_SYSADDON_NAME}" ! -iname ".*"`"

			if [ -f "${GS_SYSADDON_SCRIPT}" ]; then

				[ -f "${GS_SYSADDON_DIR}/.status" ] && GS_SYSADDON_STATUS="`sed -n "/^${GS_SYSADDON_NAME} .*$/p" "${GS_SYSADDON_DIR}/.status"`" || GS_SYSADDON_STATUS=""

				# Process installation
				if [ "${GS_SYSADDON_ACTION}" == "install" ]; then
					if [ x"${GS_SYSADDON_STATUS}" == x"" ]; then
						echo -e "\nStarting installation of add-on '${GS_SYSADDON_NAME}' ...\n"
						export OS_DISTRIBUTION
						export OS_VERSION
						export OS_VERSION_MAJOR
						export OS_CODENAME
						bash ${GS_SYSADDON_SCRIPT} install
						if [ $? != 0 ]; then
							echo -e "\n\n***    ------------------------------------------------------------------"
							echo -e "***     ERROR: Installation of add-on '${GS_SYSADDON_NAME}' FAILED!"
							echo -e "***    ------------------------------------------------------------------\n\n"
							exit 1
						else
							echo -e "\n\n***    ------------------------------------------------------------------"
							echo -e "***     Add-on '${GS_SYSADDON_NAME}' was INSTALLED SUCCESSFULLY!"
							echo -e "***    ------------------------------------------------------------------\n\n"
							echo "${GS_SYSADDON_NAME} `date +'%Y-%m-%d_%T'`" >> "${GS_SYSADDON_DIR}/.status"
						fi
					else
						echo -e "\n\n***    ------------------------------------------------------------------"
						echo -e "***     Add-on '${GS_SYSADDON_NAME}' was already installed on ${GS_SYSADDON_STATUS#* }."
						echo -e "***    ------------------------------------------------------------------\n\n"
					fi

				# Process removal
				elif [ "${GS_SYSADDON_ACTION}" == "remove" ]; then
					if [ x"${GS_SYSADDON_STATUS}" != x"" ]; then
						echo -e "\nRemoving add-on '${GS_SYSADDON_NAME}' ...\n"
						export OS_DISTRIBUTION
						export OS_VERSION
						export OS_VERSION_MAJOR
						export OS_CODENAME
						bash ${GS_SYSADDON_SCRIPT} remove
						if [ $? != 0 ]; then
							echo -e "\n\n***    ------------------------------------------------------------------"
							echo -e "***     ERROR: Removal of add-on '${GS_SYSADDON_NAME}' FAILED!"
							echo -e "***    ------------------------------------------------------------------\n\n"
							exit 1
						else
							echo -e "\n\n***    ------------------------------------------------------------------"
							echo -e "***     Add-on '${GS_SYSADDON_NAME}' was REMOVED SUCCESSFULLY!"
							echo -e "***    ------------------------------------------------------------------\n\n"
							sed -i "/^${GS_SYSADDON_NAME} .*$/d" "${GS_SYSADDON_DIR}/.status"
						fi
					else
						echo -e "\n\n***    ------------------------------------------------------------------"
						echo -e "***     Add-on '${GS_SYSADDON_NAME}' is currently not installed."
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
				echo -e "***     The specified system add-on '${GS_SYSADDON_NAME}'"
				echo -e "***     does not exist or is not available for your system."
				echo -e "***    ------------------------------------------------------------------\n\n"
				exit 1
			fi
		else
			echo -e "\n\n***    ------------------------------------------------------------------"
			echo -e "***     FATAL ERROR: ${GS_SYSADDON_DIR} not found."
			echo -e "***    ------------------------------------------------------------------\n\n"
			exit 3
		fi
		;;

	status)
		if [ x"${GS_SYSADDON_NAME}" == x"" ]; then
			[ -f "${GS_SYSADDON_DIR}/.status" ] && LIST="`cat "${GS_SYSADDON_DIR}/.status"`" || LIST=""
			[ x"${LIST}" != x"" ] && echo -e "\nThe following add-ons are currently installed:\n${LIST}\n" || echo -e "\nCurrently there are no add-ons installed.\n"
		else
			[ -f "${GS_SYSADDON_DIR}/.status" ] && GS_SYSADDON_STATUS="`sed -n "/^${GS_SYSADDON_NAME} .*$/p" "${GS_SYSADDON_DIR}/.status"`" || GS_SYSADDON_STATUS=""
			[ x"${GS_SYSADDON_STATUS}" != x"" ] && echo -e "\nThe system add-on '${GS_SYSADDON_NAME}' was installed on ${GS_SYSADDON_STATUS#* }.\n" || echo -e "\nThe system add-on '${GS_SYSADDON_NAME}' is currently not installed.\n"
		fi
		;;

	list|search)
		[ x"${GS_SYSADDON_NAME}" != x"" ] && SEARCHSTRING="*${GS_SYSADDON_NAME}*" || SEARCHSTRING="*"

		[ -d "${GS_SYSADDON_DIR}/${OS_CODENAME}" ] && LIST="`find "${GS_SYSADDON_DIR}/${OS_CODENAME}" -maxdepth 1 -type f -name "${SEARCHSTRING}" ! -iname ".*" | sort`"
		if [ x"${LIST}" != x"" ]; then
			echo -e "\nADD-ONS FOR ${OS_DISTRIBUTION^^} ${OS_CODENAME^^}"
			for GS_SYSADDON_SCRIPT in ${LIST}; do
				GS_SYSADDON_SCRIPT_BASE="`basename "${GS_SYSADDON_SCRIPT}"`"
				[ -f "${GS_SYSADDON_DIR}/.status" ] && GS_SYSADDON_STATUS="`sed -n "/^${GS_SYSADDON_SCRIPT_BASE} .*$/p" "${GS_SYSADDON_DIR}/.status"`" || GS_SYSADDON_STATUS=""
				[ x"${GS_SYSADDON_STATUS}" == x"" ] && echo -n "  " || echo -n "* "
				bash "${GS_SYSADDON_SCRIPT}" info
			done
		elif [ x"${GS_SYSADDON_NAME}" != x"" ]; then
			echo -e "\nADD-ONS FOR ${OS_DISTRIBUTION^^} ${OS_CODENAME^^}"
			echo "  No matching add-ons found."
		fi

		[ -d "${GS_SYSADDON_DIR}" ] && LIST="`find "${GS_SYSADDON_DIR}" -maxdepth 1 -type f -name "${SEARCHSTRING}" ! -iname ".*" | sort`"
		echo -e "\nGENERAL ADD-ONS"
		if [ x"${LIST}" != x"" ]; then
			for GS_SYSADDON_SCRIPT in ${LIST}; do
				GS_SYSADDON_SCRIPT_BASE="`basename "${GS_SYSADDON_SCRIPT}"`"
				[ -f "${GS_SYSADDON_DIR}/.status" ] && GS_SYSADDON_STATUS="`sed -n "/^${GS_SYSADDON_SCRIPT_BASE} .*$/p" "${GS_SYSADDON_DIR}/.status"`" || GS_SYSADDON_STATUS=""
				[ x"${GS_SYSADDON_STATUS}" == x"" ] && echo -n "  " || echo -n "* "
				bash "${GS_SYSADDON_SCRIPT}" info
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
