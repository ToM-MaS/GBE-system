#!/bin/bash
#
# Gemeinschaft 5
# Update script
#
# Copyright (c) 2013, Julian Pawlowski <jp@jps-networks.eu>
# See LICENSE.GBE file for details.
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
[ -f "${GS_MYSQL_PASSWORD_FILE}" ] && GS_MYSQL_PASSWD="`cat "${GS_MYSQL_PASSWORD_FILE}"`" || echo "FATAL ERROR: GS lost it's database password in ${GS_MYSQL_PASSWORD_FILE}"
[[ x"${GS_DIR}" == x"" || x"${GS_MYSQL_PASSWD}" == x"" ]] && exit 1
GS_UPDATE_DIR="${GS_DIR}.update"

# check each command return codes for errors
#
set -e

# Run switcher
#
case "$1" in
	--help|-h|help)
	echo "Usage: $0 [--cancel | --factory-reset]"
	exit 0
	;;

	--cancel)
	MODE="cancel"
	if [[ -d "${GS_UPDATE_DIR}" ]];
		then
		rm -rf ${GS_UPDATE_DIR}
		echo "Planned update task was canceled."
		exit 0
	else
		echo "No planned update task found."
		exit 1
	fi
	;;

	--factory-reset)
	MODE="factory-reset"
	while true; do
    	echo "ATTENTION! This will do a factory reset, all your data will be LOST!"
    	read -p "Continue? (y/N) : " yn

    	case $yn in
        	Y|y )
				[ -f /root/.mysql_root_password ] && MYSQL_PASSWD_ROOT="`cat /root/.mysql_root_password`" || exit 1

				# use local copy of GS5 for re-installation in case there is no update available
				[ ! -d "${GS_UPDATE_DIR}" ] && cp -pr "${GS_DIR}" "${GS_UPDATE_DIR}"

				# Do hard reset of repo to ensure correct files
				cd "${GS_UPDATE_DIR}"
				git clean -fdx && git reset --hard HEAD

				# stop services
				[[ `service mon_ami status` ]] && service mon_ami stop
				[[ `service freeswitch status` ]] && service freeswitch stop
				[[ `service apache2 status` ]] && service apache2 stop

				# Purging database
				echo -e "\nPurging database '${GS_MYSQL_DB}' ...";
				mysql -e "DROP DATABASE IF EXISTS ${GS_MYSQL_DB}; CREATE DATABASE ${GS_MYSQL_DB};" --user=root --password="${MYSQL_PASSWD_ROOT}"
				[[ `service mysql status` ]] && service mysql stop

				echo "Purging local FreeSwitch files ..."
				rm -rfv "${GS_DIR_LOCAL_NORMALIZED}/freeswitch/conf/"* \
					"${GS_DIR_LOCAL_NORMALIZED}/freeswitch/storage/"* \
					"${GS_DIR_LOCAL_NORMALIZED}/freeswitch/recordings/"* \
					"${GS_DIR_LOCAL_NORMALIZED}/freeswitch/voicemail/"* \
					"${GS_DIR_LOCAL_NORMALIZED}/freeswitch/db/"*

				echo -e "\n\n***    ------------------------------------------------------------------"
				echo -e "***     Factory reset complete.\n***     The system will reboot NOW!"
				echo -e "***    ------------------------------------------------------------------\n\n"
				sleep 2
				reboot

				break
			;;

        	* )
				echo "Aborting ...";
				break
			;;
    	esac

		exit
	done
	;;

	--force-init)
	MODE="init"
	;;

	--force-update)
	MODE="update"
	;;

	--force-update-init)
	MODE="update-init"
	;;
	
	*)
	MODE="update-init"

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
***     GEMEINSCHAFT UPDATE
***     Current version: ${GS_VERSION}
***     Branch: ${GS_BRANCH}
***     Base System Build: ${GS_BUILDNAME}
***    ------------------------------------------------------------------
***
***     ATTENTION! Please read the following information CAREFULLY!
***     ===========================================================
***
***     This script will prepare your system to upgrade to the latest GS5
***     source code.
***     Updating the system via this script is NOT supported, we
***     recommend to use the backup/restore function via the web
***     interface instead. This will also ensure the latest system
***     environment is used.
***
***     ! ALWAYS DO A BACKUP OF YOUR CONFIGURATION FIRST !
***
***     The system environment is not fully upgradeable which might lead
***     to a non-functional system after the update. If that is the case
***     you need to do a clean installation and restore from your backup.
"

	while true; do
	    read -p "If you understand the risk, please confirm by entering \"OK\" : " yn
	    case $yn in
	        OK|ok ) echo -e "\nRisk accepted.\n\n"; break;;
	        * ) echo "Aborting ..."; exit;;
	    esac
	done

	;;
esac

# Prepare for system update
#
if [[ "${MODE}" == "update-init" ]]; then

	echo -e "Preparing update of Gemeinschaft ...\n"

	# Remove any old update files
	[[ -d "${GS_UPDATE_DIR}" ]] && rm -rf "${GS_UPDATE_DIR}"
	[[ -d "${GS_UPDATE_DIR}.tmp" ]] && rm -rf "${GS_UPDATE_DIR}.tmp"
	
	# Make a copy of current files
	cp -r "${GS_DIR}" "${GS_UPDATE_DIR}.tmp"
	cd "${GS_UPDATE_DIR}.tmp"

	# use master branch if no explicit branch was given and GBE branch is master
	[[ x"${GS_BRANCH}" == x"" && x"${GDFDL_BRANCH}" == x"develop" ]] && GS_BRANCH="develop"
	[[ x"${GS_BRANCH}" == x"" && x"${GDFDL_BRANCH}" != x"develop" ]] && GS_BRANCH="master"

	# Add Git remote data to pull from it
	git clean -fdx && git reset --hard HEAD
	git remote add -t "${GS_BRANCH}" origin "${GS_GIT_URL}"

	# Setup Github user credentials for login
	#
	if [ ! -z "${GS_GIT_USER}" -a ! -z "${GS_GIT_PASSWORD}" ]
		then
		echo "Github credentials found!"
echo "machine Github.com
login ${GS_GIT_USER}
password ${GS_GIT_PASSWORD}
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
		git pull origin "${GS_BRANCH}" 2>&1
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

	# Make sure we checkout the latest tagged version in case we are in the master branch, otherwise set HEAD to the latest revision of GS_BRANCH
	[ "${GS_BRANCH}" == "master" ] && git checkout "`git tag -l | tail -n1`" || git checkout "${GS_BRANCH}"

	# Check version compatibility, allow auto-update only for minor versions
	GS_GIT_VERSION="`git tag --contains HEAD`"
	GS_REVISION="`git --git-dir="${GS_DIR}/.git" rev-parse HEAD`"
	GS_GIT_REVISION="`git rev-parse HEAD`"
	if [[ "${GS_GIT_REVISION}" == "${GS_REVISION}" ]]; then
		rm -rf "${GS_UPDATE_DIR}"*
		echo -e "\n\n***    ------------------------------------------------------------------"
		echo -e "***     You have already installed the latest version, no update needed."
		echo -e "***    ------------------------------------------------------------------\n\n"
		exit 0
	elif [[ "${GS_GIT_VERSION:0:3}" == "${GS_VERSION:0:3}" || x"${GS_GIT_VERSION}" == x"" ]]; then
		[ "${GS_BRANCH}" != "master" ] && GS_GIT_VERSION="from ${GS_BRANCH} branch"
		mv "${GS_UPDATE_DIR}.tmp" "${GS_UPDATE_DIR}"
		echo -e "\n\n***    ------------------------------------------------------------------"
		echo -e "***     Scheduled update to new version ${GS_GIT_VERSION}.\n***     Please reboot the system to start the update process."
		echo -e "***    ------------------------------------------------------------------\n\n"
	else
		rm -rf "${GS_UPDATE_DIR}"*
		echo -e "\n\n***    ------------------------------------------------------------------"
		echo -e "***     Update to the next major version ${GS_GIT_VERSION} is not supported\n***     via this script.\n***     Please use backup & restore via web interface."
		echo -e "***    ------------------------------------------------------------------\n\n"
		exit 1
	fi
fi

# Initialize update
#
if [[ "${MODE}" == "update" ]]; then
	if [[ -d "${GS_UPDATE_DIR}" ]]; then
		# make sure only mysql is running
		[[ `service mon_ami status` ]] && service mon_ami stop
		[[ `service freeswitch status` ]] && service freeswitch stop
		[[ `service apache2 status` ]] && service apache2 stop
		[[ `service mysql status` != 0 ]] && service mysql start

		echo "** Rename and backup old files in \"${GS_DIR}\""
		[ ! -d "${GS_DIR} ${GS_DIR}.${GS_VERSION}" ] && mv "${GS_DIR}" "${GS_DIR}.${GS_VERSION} "|| rm -rf "${GS_DIR}"
		cp -r ${GS_UPDATE_DIR} ${GS_DIR}
	else
		echo "ERROR: No new version found in \"${GS_UPDATE_DIR}\" - aborting ..."
		exit 1
	fi	
fi

# Run essential init and update commands
#
if [[ "${MODE}" == "init" || "${MODE}" == "update" ]]; then
	# Remove Git remote reference
	#
	echo "** Remove Git remote reference"
	GS_GIT_REMOTE="`git --git-dir="${GS_DIR_NORMALIZED}/.git" remote`"
	for _REMOTE in ${GS_GIT_REMOTE}; do
		cd "${GS_DIR_NORMALIZED}"; git remote rm ${_REMOTE}
	done

	echo "** Setup logging directory"
	rm -rf "${GS_DIR}/log"
	ln -sf /var/log/gemeinschaft "${GS_DIR}/log"

	echo "** Copy FreeSwitch static configuration files"
	cp -an ${GS_DIR}/misc/freeswitch/conf ${GS_DIR_LOCAL}/freeswitch

	echo "** Updating FreeSwitch with database password"
	sed -i "s/<param name=\"core-db-dsn\".*/<param name=\"core-db-dsn\" value=\"${GS_MYSQL_DB}:${GS_MYSQL_USER}:${GS_MYSQL_PASSWD}\"\/>/" "${GS_DIR_NORMALIZED_LOCAL}/freeswitch/conf/freeswitch.xml"

	# Enforce debug level according to GS_ENV
	#
	"${GSE_DIR_NORMALIZED}/bin/gs-change-state.sh"

	# Special tasks for update only
	#
	if [[ "${MODE}" == "update" ]]; then
		echo "** Enforcing file permissions and security settings ..."
		"${GSE_DIR_NORMALIZED}/bin/gs-enforce-security.sh" | grep -Ev retained | grep -Ev "no changes" | grep -Ev "nor referent has been changed"

		echo "** Install Gems"
		su - ${GS_USER} -c "cd \"${GS_DIR_NORMALIZED}\"; RAILS_ENV=$RAILS_ENV bundle install"
	fi

	# Load database structure into DB
	#
	echo "** Initializing database"
	su - ${GS_USER} -c "cd \"${GS_DIR_NORMALIZED}\"; RAILS_ENV=$RAILS_ENV bundle exec rake db:migrate --trace"

	# Generate assets (like CSS)
	#
	echo "** Precompile GS assets"
	su - ${GS_USER} -c "cd \"${GS_DIR_NORMALIZED}\"; RAILS_ENV=$RAILS_ENV bundle exec rake assets:precompile --trace"
fi

# Finalize update
#
if [[ "${MODE}" == "update" ]]; then
	# Remove update files after successful update run
	# otherwise keep them to be installed within next iteration of boot sequence
	rm -rf "${GS_UPDATE_DIR}"
fi
