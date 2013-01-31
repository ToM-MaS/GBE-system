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
[ -f /etc/gemeinschaft/system.conf ] && source /etc/gemeinschaft/system.conf || echo "FATAL ERROR: Local configuration file in /etc/gemeinschaft/system.conf missing"
[[ x"${GSE_DIR}" == x"" ]] && exit 1
GSE_UPDATE_DIR="${GSE_DIR}.update"

# check each command return codes for errors
#
set -e

# Run switcher
#
case "$1" in
	--help|-h|help)
	echo "Usage: $0 [ --factory-reset ]"
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

	echo -e "Preparing update of Gemeinschaft System Environment ...\n"

	# Remove any old update files
	[[ -d "${GSE_UPDATE_DIR}" ]] && rm -rf "${GSE_UPDATE_DIR}"
	[[ -d "${GSE_UPDATE_DIR}.tmp" ]] && rm -rf "${GSE_UPDATE_DIR}.tmp"
	
	# Make a copy of current files
	cp -r "${GSE_DIR}" "${GSE_UPDATE_DIR}.tmp"
	cd "${GSE_UPDATE_DIR}.tmp"

	# Add Git remote data to pull from it
	git clean -fdx && git reset --hard HEAD
	git remote add -t "${GSE_BRANCH}" origin "${GSE_GIT_URL}"

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
		git remote update 2>&1
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
		git pull origin "${GSE_BRANCH}" 2>&1
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
	[ "${GSE_BRANCH}" == "master" ] && git checkout "`git tag -l | tail -n1`" || git checkout "${GSE_BRANCH}"

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
	rm /usr/bin/gs-*
	rm /usr/bin/gse-*
	
	# Revert symlinks for static system files
	#
	GSE_FILES_STATIC="`find static/ -type f`"
	for _FILE in ${GSE_FILES_STATIC}; do
		# strip prefix "static/"
		GSE_FILE_SYSTEMPATH="/${_FILE#*/}"

		# Delete file
		echo -e "** Deleting file '${GSE_FILE_SYSTEMPATH}'"
		rm -f "${GSE_FILE_SYSTEMPATH}"

		# Restore original file if existing
		if [ -e "${GSE_FILE_SYSTEMPATH}.default-gse" ]; then
			echo -e "** Recovering original file '${GSE_FILE_SYSTEMPATH}' from backup"
			mv -f "${GSE_FILE_SYSTEMPATH}.default-gse" "${GSE_FILE_SYSTEMPATH}"
		fi
	done

	# Remove dynamic configuration files
	#
	GSE_FILES_DYNAMIC="`find dynamic/ -type f`"
	for _FILE in ${GSE_FILES_DYNAMIC}; do
		# strip prefix "dynamic/"
		GSE_FILE_SYSTEMPATH="/${_FILE#*/}"

		# Delete file
		echo -e "** Deleting file '${GSE_FILE_SYSTEMPATH}'"
		rm -f "${GSE_FILE_SYSTEMPATH}"

		# Restore original file if existing
		if [ -e "${GSE_FILE_SYSTEMPATH}.default-gse" ]; then
			echo -e "** Recovering original file '${GSE_FILE_SYSTEMPATH}' from backup"
			mv -f "${GSE_FILE_SYSTEMPATH}.default-gse" "${GSE_FILE_SYSTEMPATH}"
		fi
	done

	# Run self-update
	#
	cd ~
	echo "** Rename and backup old files in \"${GSE_DIR}\""
	if [ ! -d "${GSE_DIR}.${GSE_VERSION}" ]; then
		echo "** Rename and backup old files in \"${GSE_DIR}\""
		mv "${GSE_DIR}" "${GSE_DIR}.${GSE_VERSION}"
	else
		echo "** Deleting old files in \"${GSE_DIR}\""
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
	git clean -fdx && git reset --hard HEAD
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

		echo -e "** Symlinking file '${GSE_FILE_SYSTEMPATH}'"

		# make sure destination path exists
		mkdir -p "${GSE_FILE_SYSTEMPATH%/*}"

		# Backup any existing file
		if [[ "${MODE}" == "init" && -e "${GSE_FILE_SYSTEMPATH}" && ! -e "${GSE_FILE_SYSTEMPATH}.default-gse" ]]; then
			echo -e "** Creating backup of original file '${GSE_FILE_SYSTEMPATH}'"
			mv -f "${GSE_FILE_SYSTEMPATH}" "${GSE_FILE_SYSTEMPATH}.default-gse"
		fi

		# Symlink file
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

		# Copy file
		if [[ "${MODE}" == "init" || "${MODE}" == "factory-reset" ]]; then
			echo -e "** Force installing file '${GSE_FILE_SYSTEMPATH}'"
			cp -df "${GSE_DIR_NORMALIZED}/${_FILE}" "${GSE_FILE_SYSTEMPATH}"
		elif [ ! -f "${GSE_FILE_SYSTEMPATH}" ]; then
			echo -e "** Installing file '${GSE_FILE_SYSTEMPATH}'"
			cp -dn "${GSE_DIR_NORMALIZED}/${_FILE}" "${GSE_FILE_SYSTEMPATH}"
		fi
	done

	# Remove Git remote reference
	echo "** Remove Git remote reference"
	GSE_GIT_REMOTE="`git --git-dir="${GSE_DIR_NORMALIZED}/.git" remote`"
	for _REMOTE in ${GSE_GIT_REMOTE}; do
		cd "${GSE_DIR_NORMALIZED}"; git remote rm ${_REMOTE}
	done

	# Enforce debug level according to GSE_ENV
	set +e
	"${GSE_DIR_NORMALIZED}/bin/gs-change-state.sh"
	set -e

	cd - 2>&1 >/dev/null
fi


# Finalize update or factory reset
#
if [[ "${MODE}" == "self-update" || "${MODE}" == "factory-reset" ]]; then
	echo "** Enforcing file permissions and security settings ..."
	set +e
	"${GSE_DIR_NORMALIZED}/bin/gs-enforce-security.sh" | grep -Ev retained | grep -Ev "no changes" | grep -Ev "nor referent has been changed"
	set -e

	# Re-generate prompt files and update version in /etc/gemeinschaft/system.conf
	/etc/init.d/gemeinschaft-prompt start

	echo -e "\n\n***    ------------------------------------------------------------------"
	echo -e "***     Task completed SUCCESSFULLY! "
	echo -e "***    ------------------------------------------------------------------\n\n"
fi
