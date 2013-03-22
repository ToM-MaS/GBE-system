#!/bin/bash
#
# Gemeinschaft 5
# Version indicator
#
# Copyright (c) 2013, Julian Pawlowski <jp@jps-networks.eu>
# See LICENSE.GSE file for details.
#

# General settings
[ -e /etc/gemeinschaft/system.conf ] && source /etc/gemeinschaft/system.conf || echo "FATAL ERROR: Local configuration file in /etc/gemeinschaft/system.conf missing"

# General functions
[ -e "${GSE_DIR_NORMALIZED}/lib/gse-functions.sh" ] && source "${GSE_DIR_NORMALIZED}/lib/gse-functions.sh" || exit 1

OS_DISTRIBUTION="`lsb_release -i -s`"
OS_CODENAME="`lsb_release -c -s`"
OS_VERSION="`lsb_release -r -s`"
OS_ARCH="`uname -m`"

echo -e "GS version: ${GS_VERSION}
GSE version: ${GSE_VERSION}
Base System Build: #${GS_BUILDNAME}
Base Distribution: ${OS_DISTRIBUTION} ${OS_VERSION} (${OS_CODENAME})
System Architecture: ${OS_ARCH}"
