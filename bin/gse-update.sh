#!/bin/bash
#
# Gemeinschaft 5
# System Environment update script
#
# Copyright (c) 2013, Julian Pawlowski <jp@jps-networks.eu>
# See LICENSE.GSE file for details.
#

# Enforce root rights
#
if [[ ${EUID} -ne 0 ]];
	then
	echo "ERROR: `basename $0` needs to be run as root. Aborting ..."
	exit 1
fi

# General settings
[ -e /etc/gemeinschaft/system.conf ] && source /etc/gemeinschaft/system.conf || echo "FATAL ERROR: Local configuration file in /etc/gemeinschaft/system.conf missing"
[[ x"${GSE_DIR}" == x"" ]] && exit 1
GSE_UPDATE_DIR="${GSE_DIR}.update"

# General functions
[ -e "${GSE_DIR_NORMALIZED}/lib/gse-functions.sh" ] && source "${GSE_DIR_NORMALIZED}/lib/gse-functions.sh" || exit 1


# check each command return codes for errors
#
set -e

# Run switcher
#
case "$1" in
	--help|-h|help)
	echo "Usage: $0 [ --factory-reset | --recover ]"
	exit 0
	;;

	--factory-reset)
	MODE="factory-reset"
	
	while true; do
		echo "ATTENTION! This will do a factory reset of the SYSTEM ENVIRONMENT, all customizations will be LOST!"
		read -p "Continue? (y/N) : " yn

		case $yn in
	    	Y|y ) break;;
	    	* )	echo "Aborting ..."; exit;;
		esac
	done
	
	;;

	--force-factory-reset)
	MODE="factory-reset"
	;;

	--force-update)
	MODE="update"
	;;

	--force-selfupdate)
	MODE="self-update"
	;;

	--force-init)
	MODE="init"
	;;

	--recover)
	MODE="recover"
	;;

	*)
	MODE="update"

	# Check for live status
	#
	if [[ x`cat /proc/cmdline | grep boot=live` != x"" ]]
		then
		echo "LIVE mode detected. Aborting ..."
		exit 1
	fi

	clear
	echo "
***    ------------------------------------------------------------------
***     GEMEINSCHAFT SYSTEM ENVIRONMENT UPDATE
***     Current GSE version: ${GSE_VERSION}
***     GSE Branch: ${GSE_BRANCH}
***     Base System Build: #${GS_BUILDNAME}
***    ------------------------------------------------------------------
***
***     ATTENTION! Please read the following information CAREFULLY!
***     ===========================================================
***
***     This script will prepare your system to upgrade to the latest
***     system environment scripts source code.
***     Updating the system environment via this script is NOT supported,
***     we recommend to use the backup/restore function via the web
***     interface instead. This will ensure also other parts of the
***     system environment are up-to-date.
***
"

	while true; do
	    read -p "Do you want to continue? (y/N) : " yn
	    case $yn in
	        y|Y ) break;;
	        * ) echo "Aborting ..."; exit;;
	    esac
	done

	;;
esac

# Prepare for system update
#
if [[ "${MODE}" == "update" ]]; then

	# Remove any old update files
	[[ -d "${GSE_UPDATE_DIR}" ]] && rm -rf "${GSE_UPDATE_DIR}"
	[[ -d "${GSE_UPDATE_DIR}.tmp" ]] && rm -rf "${GSE_UPDATE_DIR}.tmp"
	
	# Make a copy of current files
	cp -r "${GSE_DIR}" "${GSE_UPDATE_DIR}.tmp"
	cd "${GSE_UPDATE_DIR}.tmp"

	# Add Git remote data to pull from it
	quiet_git clean -fdx && quiet_git reset --hard HEAD
	quiet_git remote add -t "${GSE_BRANCH}" origin "${GSE_GIT_URL}"

	# Setup Github user credentials for login
	#
	if [ ! -z "${GSE_GIT_USER}" -a ! -z "${GSE_GIT_PASSWORD}" ]
		then
		echo "Github credentials found!"
echo "machine Github.com
login ${GSE_GIT_USER}
password ${GSE_GIT_PASSWORD}
" >  ~/.netrc
	fi

	set +e
	c=1
	while [[ $c -le 5 ]]
	do
		quiet_git remote update
		if [ "$?" = "0" ]
			then
			break;
		else
			[[ $c -eq 5 ]] && exit 1
			(( c++ ))
			echo "$c. try in 3 seconds ..."
			sleep 3
		fi
	done

	c=1
	while [[ $c -le 5 ]]
	do
		quiet_git pull origin "${GSE_BRANCH}"
		if [ "$?" -eq "0" ]
			then
			break;
		else
			[[ $c -eq 5 ]] && exit 1
			(( c++ ))
			echo "$c. try in 3 seconds ..."
			sleep 3
		fi
	done
	set -e

	rm -rf ~/.netrc

	# Make sure we checkout the latest tagged version in case we are in the master branch, otherwise set HEAD to the latest revision of GSE_BRANCH
	[ "${GSE_BRANCH}" == "master" ] && quiet_git checkout "`git tag -l | tail -n1`" || quiet_git checkout "${GSE_BRANCH}"

	# Check version compatibility, allow auto-update only for minor versions
	GSE_GIT_VERSION="`git tag --contains HEAD`"
	GSE_REVISION="`git --git-dir="${GSE_DIR}/.git" rev-parse HEAD`"
	GSE_GIT_REVISION="`git rev-parse HEAD`"
	if [[ "${GSE_GIT_REVISION}" == "${GSE_REVISION}" ]]; then
		rm -rf "${GSE_UPDATE_DIR}"*
		echo -e "\n\n***    ------------------------------------------------------------------"
		echo -e "***     System Environment is already up-to-date, no update needed."
		echo -e "***    ------------------------------------------------------------------\n\n"
		exit 0
	elif [[ "${GSE_GIT_VERSION:0:3}" == "${GSE_VERSION:0:3}" || x"${GSE_GIT_VERSION}" == x"" ]]; then
		[ "${GSE_BRANCH}" != "master" ] && GSE_GIT_VERSION="from ${GSE_BRANCH} branch"
		mv "${GSE_UPDATE_DIR}.tmp" "${GSE_UPDATE_DIR}"
		echo -e "\n\n***    ------------------------------------------------------------------"
		echo -e "***     Updating System Environment to new version ${GSE_GIT_VERSION}"
		echo -e "***    ------------------------------------------------------------------\n\n"
	else
		rm -rf "${GSE_UPDATE_DIR}"*
		echo -e "\n\n***    ------------------------------------------------------------------"
		echo -e "***     Updating GSE to the next major version ${GSE_GIT_VERSION} is not supported\n***     via this script.\n***     Please use backup & restore via web interface."
		echo -e "***    ------------------------------------------------------------------\n\n"
		exit 1
	fi

	# Uninstall
	#

	cd "${GSE_DIR_NORMALIZED}"

	# remove public commands
	rm -rf /usr/bin/gs-*
	rm -rf /usr/bin/gse-*
	
	# Revert symlinks for static system files
	#
	GSE_FILES_STATIC="`find static/ -type f`"
	for _FILE in ${GSE_FILES_STATIC}; do
		# strip prefix "static/"
		GSE_FILE_SYSTEMPATH="/${_FILE#*/}"

		# Delete file
		rm -f "${GSE_FILE_SYSTEMPATH}"

		# Restore original file if existing
		if [ -e "${GSE_FILE_SYSTEMPATH}.default-gse" ]; then
			mv -f "${GSE_FILE_SYSTEMPATH}.default-gse" "${GSE_FILE_SYSTEMPATH}"
		fi
	done

	# Remove dynamic configuration files
	#
	GSE_FILES_DYNAMIC="`find dynamic/ -type f`"
	for _FILE in ${GSE_FILES_DYNAMIC}; do
		# strip prefix "dynamic/"
		GSE_FILE_SYSTEMPATH="/${_FILE#*/}"

		if [ -e "${GSE_FILE_SYSTEMPATH}" ]; then
			set +e
			diff -q "${_FILE}" "${GSE_FILE_SYSTEMPATH}" >/dev/null
			FILE_CHANGE_STATUS="$?"
			set -e

			# Delete file if it hasn't been changed by the user
			if [ "${FILE_CHANGE_STATUS}" == "0" ]; then
				rm -f "${GSE_FILE_SYSTEMPATH}"
			else
				echo -e "** Keeping user modified file '${GSE_FILE_SYSTEMPATH}' and leaving it untouched"
			fi
		fi

		# Restore original file if it was existing before and we didn't keep the users file
		if [[ -e "${GSE_FILE_SYSTEMPATH}.default-gse" && ! -e "${GSE_FILE_SYSTEMPATH}" ]]; then
			cp -df "${GSE_FILE_SYSTEMPATH}.default-gse" "${GSE_FILE_SYSTEMPATH}"
		fi
	done

	# Run self-update
	#
	cd ~
	if [ ! -d "${GSE_DIR}-${GSE_VERSION}" ]; then
		mv "${GSE_DIR}" "${GSE_DIR}-${GSE_VERSION}"
	else
		rm -rf "${GSE_DIR}"
	fi
	mv "${GSE_UPDATE_DIR}" "${GSE_DIR}"
	"${GSE_DIR_NORMALIZED}/bin/gse-update.sh" --force-selfupdate
	exit $?
fi

# Factory reset
#
if [[ "${MODE}" == "factory-reset" ]]; then
	cd "${GSE_DIR_NORMALIZED}"
	quiet_git clean -fdx && quiet_git reset --hard HEAD
fi

# Run essential init and update commands
#
if [[ "${MODE}" == "init" || "${MODE}" == "self-update" || "${MODE}" == "factory-reset" ]]; then
	# Symlink public commands
	ln -sf "${GSE_DIR_NORMALIZED}/bin/gs-update.sh" /usr/bin/gs-update
	ln -sf "${GSE_DIR_NORMALIZED}/bin/gse-update.sh" /usr/bin/gse-update
	ln -sf "${GSE_DIR_NORMALIZED}/bin/gs-addon.sh" /usr/bin/gs-addon

	cd "${GSE_DIR_NORMALIZED}"

	# Symlink static system files users should not need to change
	#
	GSE_FILES_STATIC="`find static/ -type f`"
	for _FILE in ${GSE_FILES_STATIC}; do
		# strip prefix "static/"
		GSE_FILE_SYSTEMPATH="/${_FILE#*/}"

		# make sure destination path exists
		mkdir -p "${GSE_FILE_SYSTEMPATH%/*}"

		# Backup any existing file
		if [[ "${MODE}" == "init" && -e "${GSE_FILE_SYSTEMPATH}" && ! -e "${GSE_FILE_SYSTEMPATH}.default-gse" ]]; then
			echo -e "** Creating backup of original file '${GSE_FILE_SYSTEMPATH}'"
			mv -f "${GSE_FILE_SYSTEMPATH}" "${GSE_FILE_SYSTEMPATH}.default-gse"
		fi

		# Symlink file
		if [[ "${MODE}" == "init" || "${MODE}" == "factory-reset" ]]; then
			echo -e "** Force symlinking file '${GSE_FILE_SYSTEMPATH}'"
		fi
		rm -f "${GSE_FILE_SYSTEMPATH}"
		ln -s "${GSE_DIR_NORMALIZED}/${_FILE}" "${GSE_FILE_SYSTEMPATH}"
	done

	# Copy dynamic configuration files users may change
	#
	GSE_FILES_DYNAMIC="`find dynamic/ -type f`"
	for _FILE in ${GSE_FILES_DYNAMIC}; do
		# strip prefix "dynamic/"
		GSE_FILE_SYSTEMPATH="/${_FILE#*/}"

		# make sure destination path exists
		mkdir -p "${GSE_FILE_SYSTEMPATH%/*}"

		# Backup any existing file
		if [[ "${MODE}" == "init" && -e "${GSE_FILE_SYSTEMPATH}" && ! -e "${GSE_FILE_SYSTEMPATH}.default-gse" ]]; then
			echo -e "** Creating backup of original file '${GSE_FILE_SYSTEMPATH}'"
			mv -f "${GSE_FILE_SYSTEMPATH}" "${GSE_FILE_SYSTEMPATH}.default-gse"
		fi

		# Check for equality of backup and original file
		set +e
		diff -q "${_FILE}" "${GSE_FILE_SYSTEMPATH}" >/dev/null
		FILE_CHANGE_STATUS="$?"
		set -e

		# Copy file
		if [[ "${MODE}" == "init" || "${MODE}" == "factory-reset" ]]; then
			echo -e "** Force installing file '${GSE_FILE_SYSTEMPATH}'"
			cp -df "${GSE_DIR_NORMALIZED}/${_FILE}" "${GSE_FILE_SYSTEMPATH}"
		elif [[ -e "${GSE_FILE_SYSTEMPATH}" && -e "${GSE_FILE_SYSTEMPATH}.default-gse" && "${FILE_CHANGE_STATUS}" == "0" ]]; then
			cp -df "${GSE_DIR_NORMALIZED}/${_FILE}" "${GSE_FILE_SYSTEMPATH}"			
		elif [ ! -e "${GSE_FILE_SYSTEMPATH}" ]; then
			cp -dn "${GSE_DIR_NORMALIZED}/${_FILE}" "${GSE_FILE_SYSTEMPATH}"
		fi
	done

	# Remove Git remote reference
	GSE_GIT_REMOTE="`git --git-dir="${GSE_DIR_NORMALIZED}/.git" remote`"
	for _REMOTE in ${GSE_GIT_REMOTE}; do
		cd "${GSE_DIR_NORMALIZED}"; quiet_git remote rm ${_REMOTE}
	done

	# Enforce debug level according to GSE_ENV
	set +e
	"${GSE_DIR_NORMALIZED}/bin/gs-change-state.sh" >/dev/null
	set -e

	cd - 2>&1 >/dev/null
fi

# Explicit recover of a single file
#
if [ "${MODE}" == "recover" ]; then
	if [ x"$2" == x"" ]; then
		echo "Please enter the exact path of the file you would like to be recovered."
		exit 1
	fi
	
	FILE="$2"
	CURRENT_PATH="`pwd`"

	# find static file via full-qualified path
	if [ -e "${GSE_DIR_NORMALIZED}/static/${FILE#/*}" ]; then
		mkdir -p "${FILE%/*}"
		rm -f "${FILE}"
		ln -s "${GSE_DIR_NORMALIZED}/static/${FILE#/*}" "${FILE}"
		echo -e "\n\n***    ------------------------------------------------------------------"
		echo -e "***     File '${FILE}'"
		echo -e "***     has been recovered from static GSE data store."
		echo -e "***    ------------------------------------------------------------------\n\n"

	# find static file via current working directory
	elif [ -e "${GSE_DIR_NORMALIZED}/static/${CURRENT_PATH#/*}/${FILE}" ]; then
		[[ ${FILE} =~ "/" ]] && mkdir -p "${CURRENT_PATH}/${FILE%/*}"
		rm -f "${CURRENT_PATH}/${FILE}"
		ln -s "${GSE_DIR_NORMALIZED}/static/${CURRENT_PATH#/*}/${FILE}" "${CURRENT_PATH}/${FILE}"
		echo -e "\n\n***    ------------------------------------------------------------------"
		echo -e "***     File '${CURRENT_PATH}/${FILE}'"
		echo -e "***     has been recovered from static GSE data store."
		echo -e "***    ------------------------------------------------------------------\n\n"

	# find dynamic file via full-qualified path
	elif [ -e "${GSE_DIR_NORMALIZED}/dynamic/${FILE#/*}" ]; then
		mkdir -p "${FILE%/*}"
		cp -df "${GSE_DIR_NORMALIZED}/dynamic/${FILE#/*}" "${FILE}"
		echo -e "\n\n***    ------------------------------------------------------------------"
		echo -e "***     File '${FILE}'"
		echo -e "***     has been recovered from dynamic GSE data store."
		echo -e "***    ------------------------------------------------------------------\n\n"

	# find dynamic file via current working directory
	elif [ -e "${GSE_DIR_NORMALIZED}/dynamic/${CURRENT_PATH#/*}/${FILE}" ]; then
		[[ ${FILE} =~ "/" ]] && mkdir -p "${CURRENT_PATH}/${FILE%/*}"
		cp -df "${GSE_DIR_NORMALIZED}/dynamic/${CURRENT_PATH#/*}/${FILE}" "${CURRENT_PATH}/${FILE}"
		echo -e "\n\n***    ------------------------------------------------------------------"
		echo -e "***     File '${CURRENT_PATH}/${FILE}'"
		echo -e "***     has been recovered from dynamic GSE data store."
		echo -e "***    ------------------------------------------------------------------\n\n"

	# If we can't find the specified file in GSE lib
	else
		echo -e "\n\n***    ------------------------------------------------------------------"
		echo -e "***     File '${FILE}'"
		echo -e "***     is not present in the GSE data store and thus cannot be recovered."
		echo -e "***    ------------------------------------------------------------------\n\n"
		exit 1
	fi
fi

# Enforce correct file permissions
#
if [[ "${MODE}" == "self-update" || "${MODE}" == "factory-reset" ]]; then
	set +e
	"${GSE_DIR_NORMALIZED}/bin/gs-enforce-security.sh" | grep -Ev retained | grep -Ev "no changes" | grep -Ev "nor referent has been changed"
	set -e
fi

# Finalize update or factory reset
#
if [[ "${MODE}" == "self-update" || "${MODE}" == "factory-reset" ]]; then
	# Read GSE version from Git repo
	#
	cd "${GSE_DIR_NORMALIZED}"
	GSE_LATEST_VERSION="`git tag -l | tail -n1`"
	GSE_CURRENT_REVISION="`git rev-parse --abbrev-ref HEAD`"
	cd - 2>&1>/dev/null

	if [[ "${GSE_CURRENT_REVISION}" == "master" || "${GSE_CURRENT_REVISION}" == "HEAD" ]]; then
		GSE_VERSION_EXTRACTED="${GSE_LATEST_VERSION}"
	else
		GSE_VERSION_MINOR="`echo ${GSE_LATEST_VERSION##*.} | sed -e 's/^.*\([0-9]\)$/\1/'`"
		GSE_VERSION_NEXT="`expr ${GSE_VERSION_MINOR} + 1`"
		GSE_VERSION_EXTRACTED="${GSE_LATEST_VERSION%${GSE_VERSION_MINOR}}${GSE_VERSION_NEXT}-${GSE_BRANCH}"
	fi

	# Update local config file
	#
	if [[ "${GSE_VERSION_EXTRACTED}" != "${GSE_VERSION}" ]]; then
		GSE_VERSION="${GSE_VERSION_EXTRACTED}"
		mv -f /etc/gemeinschaft/system.conf /etc/gemeinschaft/system.conf.bak
		egrep -Ev "^GSE_VERSION=" /etc/gemeinschaft/system.conf.bak > /etc/gemeinschaft/system.conf
		echo "GSE_VERSION=\"${GSE_VERSION}\"" >> /etc/gemeinschaft/system.conf
	fi
fi
