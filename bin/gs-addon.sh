#!/bin/bash
#
# Gemeinschaft 5
# System add-on installer
#
# Copyright (c) 2013, Julian Pawlowski <jp@jps-networks.eu>
# See LICENSE.GSE file for details.
#

# General settings
[ -e /etc/gemeinschaft/system.conf ] && source /etc/gemeinschaft/system.conf || echo "FATAL ERROR: Local configuration file in /etc/gemeinschaft/system.conf missing"

# General functions
[ -e "${GSE_DIR_NORMALIZED}/lib/gse-functions.sh" ] && source "${GSE_DIR_NORMALIZED}/lib/gse-functions.sh" || exit 1


GSE_ADDON_DIR="${GSE_DIR_NORMALIZED}/lib/addons"
GSE_ADDON_STATUSFILE="/var/local/.gse_addon_status"

# Enforce root rights
#
if [[ ${EUID} -ne 0 ]];
	then
	echo "ERROR: `basename $0` needs to be run as root. Aborting ..."
	exit 1
fi

OS_DISTRIBUTION="`lsb_release -i -s`"
OS_CODENAME="`lsb_release -c -s`"
OS_VERSION="`lsb_release -r -s`"
OS_ARCH="`uname -m`"

# Check for supported distribution
if [ "${OS_DISTRIBUTION,,}" != "debian" ]; then
	echo "ERROR: Linux distribution ${OS_DISTRIBUTION} is currently not supported. Aborting ..."
	exit 1
fi

# Check for supported distribution codename
if [ "${OS_CODENAME,,}" != "wheezy" ]; then
	echo "ERROR: ${OS_DISTRIBUTION} ${OS_VERSION} (${OS_CODENAME}) is currently not supported. Aborting ..."
	exit 1
fi

# Harmonize architectures
[ "${OS_ARCH,,}" == "i486" ] && OS_ARCH="i386"
[ "${OS_ARCH,,}" == "i586" ] && OS_ARCH="i386"
[ "${OS_ARCH,,}" == "i686" ] && OS_ARCH="i386"

# Detect scriptmode
[[ "$@" =~ "scriptmode" ]] && SCRIPTMODE=true || SCRIPTMODE=false

# Run switcher
#
if [[ "${SCRIPTMODE}" == "false" ]]; then
echo -e "***    ------------------------------------------------------------------
***     GEMEINSCHAFT SYSTEM ADD-ON MANAGEMENT v${GSE_VERSION}
***     Base System Build: #${GS_BUILDNAME}
***    ------------------------------------------------------------------"
fi

GSE_ADDON_ACTION="$1"
GSE_ADDON_NAME="$2"

case "${GSE_ADDON_ACTION}" in
	install|update|remove)
		if [[ x"${GSE_ADDON_NAME}" ==  x"" && "${GSE_ADDON_ACTION}" != "update" ]]; then
			echo -e "\n\nPlease specify an add-on name.\n"
			exit 1
		fi
		if [ -d "${GSE_ADDON_DIR}" ]; then

			# Try to find the specified add-on script
			[ -d "${GSE_ADDON_DIR}/${OS_CODENAME}" ] && GSE_ADDON_SCRIPT="`find "${GSE_ADDON_DIR}/${OS_CODENAME}" -maxdepth 1 -type f -name "${GSE_ADDON_NAME}" ! -iname ".*"`" || GSE_ADDON_SCRIPT=""
			[ "${GSE_ADDON_SCRIPT}" == "" ] && GSE_ADDON_SCRIPT="`find "${GSE_ADDON_DIR}" -maxdepth 1 -type f -name "${GSE_ADDON_NAME}" ! -iname ".*"`"

			if [ -e "${GSE_ADDON_SCRIPT}" ]; then

				[[ -e "${GSE_ADDON_STATUSFILE}" && x"${GSE_ADDON_NAME}" !=  x"" ]] && GSE_ADDON_STATUS="`sed -n "/^${GSE_ADDON_NAME} .*$/p" "${GSE_ADDON_STATUSFILE}"`" || GSE_ADDON_STATUS=""
				[ x"${GSE_ADDON_STATUS}" != x"" ] && GSE_ADDON_VERSION_INSTALLED="`echo ${GSE_ADDON_STATUS} | cut -d " " -f3`" || GSE_ADDON_VERSION_INSTALLED=""
				[ x"${GSE_ADDON_STATUS}" != x"" ] && GSE_ADDON_INSTALLDATE="`echo ${GSE_ADDON_STATUS} | cut -d " " -f2`" || GSE_ADDON_INSTALLDATE=""
				[ x"${GSE_ADDON_SCRIPT}" != x"" ] && GSE_ADDON_VERSION="`bash ${GSE_ADDON_SCRIPT} version`" || GSE_ADDON_VERSION=""

				# Process installation
				if [ "${GSE_ADDON_ACTION}" == "install" ]; then
					if [ x"${GSE_ADDON_STATUS}" == x"" ]; then
						echo -e "\nStarting installation of add-on '${GSE_ADDON_NAME}' version ${GSE_ADDON_VERSION} ...\n"
						export OS_DISTRIBUTION
						export OS_CODENAME
						export OS_VERSION
						export OS_ARCH
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
							echo "${GSE_ADDON_NAME} `date +'%Y-%m-%d_%T'` ${GSE_ADDON_VERSION}" >> "${GSE_ADDON_STATUSFILE}"
						fi
					else
						echo -e "\nAdd-on '${GSE_ADDON_NAME}' is already installed.\n"
						$0 update ${GSE_ADDON_NAME}
						exit 0
					fi

				# Process update
				elif [ "${GSE_ADDON_ACTION}" == "update" ]; then
					if [ x"${GSE_ADDON_STATUS}" != x"" ]; then
						GSE_ADDON_VERSION_INSTALLED="`echo ${GSE_ADDON_STATUS} | cut -d " " -f3`"
						
						if [ "${GSE_ADDON_VERSION_INSTALLED}" != "${GSE_ADDON_VERSION}" ]; then
							echo -e "\nStarting update of add-on '${GSE_ADDON_NAME}' to new version ${GSE_ADDON_VERSION} ...\n"
							export OS_DISTRIBUTION
							export OS_CODENAME
							export OS_VERSION
							export OS_ARCH
							bash ${GSE_ADDON_SCRIPT} update
							if [ $? != 0 ]; then
								echo -e "\n\n***    ------------------------------------------------------------------"
								echo -e "***     ERROR: Update of add-on '${GSE_ADDON_NAME}' FAILED!"
								echo -e "***    ------------------------------------------------------------------\n\n"
								exit 1
							else
								echo -e "\n\n***    ------------------------------------------------------------------"
								echo -e "***     Add-on '${GSE_ADDON_NAME}' was UPDATED SUCCESSFULLY!"
								echo -e "***    ------------------------------------------------------------------\n\n"
								sed -i "/^${GSE_ADDON_NAME} .*$/d" "${GSE_ADDON_STATUSFILE}"
								echo "${GSE_ADDON_NAME} `date +'%Y-%m-%d_%T'` ${GSE_ADDON_VERSION}" >> "${GSE_ADDON_STATUSFILE}"
							fi
						else
							echo -e "\n\n***    ------------------------------------------------------------------"
							echo -e "***     Add-on '${GSE_ADDON_NAME}' is already UP-TO-DATE, no update needed."
							echo -e "***    ------------------------------------------------------------------\n\n"
						fi
					else
						echo -e "\n\n***    ------------------------------------------------------------------"
						echo -e "***     Add-on '${GSE_ADDON_NAME}' is currently not installed."
						echo -e "***    ------------------------------------------------------------------\n\n"
						exit 1
					fi

				# Process removal
				elif [ "${GSE_ADDON_ACTION}" == "remove" ]; then
					if [ x"${GSE_ADDON_STATUS}" != x"" ]; then
						echo -e "\nRemoving add-on '${GSE_ADDON_NAME}' ...\n"
						export OS_DISTRIBUTION
						export OS_CODENAME
						export OS_VERSION
						export OS_ARCH
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
				
			# Update all installed add-ons at once
			elif [ "${GSE_ADDON_ACTION}" == update ]; then
				UPDATE_FAILURES=false
				UPDATE_AVAILABLE=false
				IFS="
"
				for ADDON in `cat "${GSE_ADDON_STATUSFILE}"`; do
					GSE_ADDON_NAME="`echo ${ADDON} | cut -d " " -f1`"
					GSE_ADDON_INSTALLDATE="`echo ${ADDON} | cut -d " " -f2`"
					GSE_ADDON_VERSION_INSTALLED="`echo ${ADDON} | cut -d " " -f3`"
					GSE_ADDON_UPDATEDATE="`echo ${ADDON} | cut -d " " -f4`"
				
					# Try to find the specified add-on script
					[ -d "${GSE_ADDON_DIR}/${OS_CODENAME}" ] && GSE_ADDON_SCRIPT="`find "${GSE_ADDON_DIR}/${OS_CODENAME}" -maxdepth 1 -type f -name "${GSE_ADDON_NAME}" ! -iname ".*"`" || GSE_ADDON_SCRIPT=""
					[ "${GSE_ADDON_SCRIPT}" == "" ] && GSE_ADDON_SCRIPT="`find "${GSE_ADDON_DIR}" -maxdepth 1 -type f -name "${GSE_ADDON_NAME}" ! -iname ".*"`"

					if [ -e "${GSE_ADDON_SCRIPT}" ]; then
						GSE_ADDON_VERSION="`bash ${GSE_ADDON_SCRIPT} version`"

						if [ "${GSE_ADDON_VERSION}" != "${GSE_ADDON_VERSION_INSTALLED}" ]; then
							UPDATE_AVAILABLE=true
							echo -e "\nStarting update of add-on '${GSE_ADDON_NAME}' to new version ${GSE_ADDON_VERSION} ...\n"
							export OS_DISTRIBUTION
							export OS_CODENAME
							export OS_VERSION
							export OS_ARCH
							bash ${GSE_ADDON_SCRIPT} update
							if [ $? != 0 ]; then
								echo -e "\n\n***    ------------------------------------------------------------------"
								echo -e "***     ERROR: Update of add-on '${GSE_ADDON_NAME}' FAILED!"
								echo -e "***    ------------------------------------------------------------------\n\n"
								UPDATE_FAILURES=true
							else
								echo -e "\n\n***    ------------------------------------------------------------------"
								echo -e "***     Add-on '${GSE_ADDON_NAME}' was UPDATED SUCCESSFULLY!"
								echo -e "***    ------------------------------------------------------------------\n\n"
								sed -i "/^${GSE_ADDON_NAME} .*$/d" "${GSE_ADDON_STATUSFILE}"
								echo "${GSE_ADDON_NAME} `date +'%Y-%m-%d_%T'` ${GSE_ADDON_VERSION}" >> "${GSE_ADDON_STATUSFILE}"
							fi
						fi

					else
						echo -e "WARNING: Add-on '${ADDON_NAME}' seems to be deprecated as no definition file was found in the library anymore."
					fi
				done

				if [ "${UPDATE_AVAILABLE}" == "false" ]; then
					echo -e "\n\n***    ------------------------------------------------------------------"
					echo -e "***      ALL system add-ons are already UP-TO-DATE, no update needed."
					echo -e "***    ------------------------------------------------------------------\n\n"
				elif [ "${UPDATE_FAILURES}" == "false" ]; then
					echo -e "\n\n***    ------------------------------------------------------------------"
					echo -e "***      ALL system add-ons were updated SUCCESSFULLY."
					echo -e "***    ------------------------------------------------------------------\n\n"
				else
					echo -e "\n\n***    ------------------------------------------------------------------"
					echo -e "***      ERRORS occurred during update of some system add-ons."
					echo -e "***      Please check the script output from above."
					echo -e "***    ------------------------------------------------------------------\n\n"
					exit 1
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

	update-check|check-update)
		if [ -e "${GSE_ADDON_STATUSFILE}" ]; then
			IFS="
"
			UPDATE_AVAILABLE=false

			for ADDON in `cat "${GSE_ADDON_STATUSFILE}"`; do
				GSE_ADDON_NAME="`echo ${ADDON} | cut -d " " -f1`"
				GSE_ADDON_INSTALLDATE="`echo ${ADDON} | cut -d " " -f2`"
				GSE_ADDON_VERSION_INSTALLED="`echo ${ADDON} | cut -d " " -f3`"
				GSE_ADDON_UPDATEDATE="`echo ${ADDON} | cut -d " " -f4`"
				
				# Try to find the specified add-on script
				[ -d "${GSE_ADDON_DIR}/${OS_CODENAME}" ] && GSE_ADDON_SCRIPT="`find "${GSE_ADDON_DIR}/${OS_CODENAME}" -maxdepth 1 -type f -name "${GSE_ADDON_NAME}" ! -iname ".*"`" || GSE_ADDON_SCRIPT=""
				[ "${GSE_ADDON_SCRIPT}" == "" ] && GSE_ADDON_SCRIPT="`find "${GSE_ADDON_DIR}" -maxdepth 1 -type f -name "${GSE_ADDON_NAME}" ! -iname ".*"`"

				if [ -e "${GSE_ADDON_SCRIPT}" ]; then
					GSE_ADDON_VERSION="`bash ${GSE_ADDON_SCRIPT} version`"
					if [ "${GSE_ADDON_VERSION}" != "${GSE_ADDON_VERSION_INSTALLED}" ]; then
						echo -e "\nNew version ${GSE_ADDON_VERSION} available for add-on ${GSE_ADDON_NAME}."
						UPDATE_AVAILABLE=true
					fi
				else
					echo -e "WARNING: Add-on '${GSE_ADDON_NAME}' seems to be deprecated as no definition file was found in the library anymore."
				fi
			done

			if [ "${UPDATE_AVAILABLE}" == "false" ]; then
				echo -e "\n\n***    ------------------------------------------------------------------"
				echo -e "***     ALL installed system add-ons are currently UP-TO-DATE."
				echo -e "***    ------------------------------------------------------------------\n\n"
			else
				echo -e "\n\n***    ------------------------------------------------------------------"
				echo -e "***     You may update all system add-ons at once by running"
				echo -e "***     'gs-addon update' or 'gs-addon update <ADD-ON>' for individual update."
				echo -e "***    ------------------------------------------------------------------\n\n"
				exit 2
			fi
		fi
		;;

	status)
		if [ x"${GSE_ADDON_NAME}" == x"" ]; then
			[ -e "${GSE_ADDON_STATUSFILE}" ] && LIST="`cat "${GSE_ADDON_STATUSFILE}"`" || LIST=""
			[ x"${LIST}" != x"" ] && echo -e "\nThe following add-ons are currently installed:\n${LIST}\n" || echo -e "\nCurrently there are no add-ons installed.\n"
		else
			[ -e "${GSE_ADDON_STATUSFILE}" ] && GSE_ADDON_STATUS="`sed -n "/^${GSE_ADDON_NAME} .*$/p" "${GSE_ADDON_STATUSFILE}"`" || GSE_ADDON_STATUS=""
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
				[ -e "${GSE_ADDON_STATUSFILE}" ] && GSE_ADDON_STATUS="`sed -n "/^${GSE_ADDON_SCRIPT_BASE} .*$/p" "${GSE_ADDON_STATUSFILE}"`" || GSE_ADDON_STATUS=""
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
				[ -e "${GSE_ADDON_STATUSFILE}" ] && GSE_ADDON_STATUS="`sed -n "/^${GSE_ADDON_SCRIPT_BASE} .*$/p" "${GSE_ADDON_STATUSFILE}"`" || GSE_ADDON_STATUS=""
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
		echo -e "\nUsage: `basename $0` [ install | update | update-check | remove | list | search | status ] <ADD-ON NAME>\n"
		exit 1
		;;
esac

exit 0
