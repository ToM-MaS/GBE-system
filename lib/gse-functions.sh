#!/bin/bash
#
# Gemeinschaft 5
# General functions for System Environment scripts
#
# Copyright (c) 2013, Julian Pawlowski <jp@jps-networks.eu>
# See LICENSE.GSE file for details.
#

quiet_git() {
    stdout=/tmp/gbe-git.stdout
    stderr=/tmp/gbe-git.stderr

    if ! git "$@" </dev/null >$stdout 2>$stderr; then
        cat $stderr >&2
        rm -f $stdout $stderr
        exit 1
    fi

    rm -f $stdout $stderr
}
