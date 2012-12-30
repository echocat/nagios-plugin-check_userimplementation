
#!/bin/sh

# --------------------------------------------------------------------
# **** BEGIN LICENSE BLOCK *****
#
# Version: MPL 2.0
#
# echocat check_user_implementation.sh, Copyright (c) 2011-2012 echocat
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# **** END LICENSE BLOCK *****
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# Check if a specified user exists and that he has the correct userId and groupId.
#
# @author: Daniel Werdermann / dwerdermann@web.de
# @projectsite: https://github.com/echocat/nagios-plugin-check_userimplementation
# @veriosn: 1.3
# @date: 2012-12-30 14:21:44Z
#
# changes 1.3
#  - update license information
# changes 1.2
#  - add license information
# changes 1.1
#  - cleanup contact information
# changes 1.0
#  - insertation of nagios standards, a few more comments and a help system
#  - implementation of logger for /var/log/messages
# --------------------------------------------------------------------


# --------------------------------------------------------------------
# configuration
# --------------------------------------------------------------------
PROGNAME=$(basename $0)
LOGGER="/bin/logger -i -p kern.warn -t"

export PATH="/bin:/usr/local/bin:/sbin:/usr/bin:/usr/sbin"
LIBEXEC="/usr/lib64/nagios/plugins /usr/lib/nagios/plugins /usr/local/nagios/libexec /usr/local/libexec"
for i in ${LIBEXEC};do
   [ -r ${i}/utils.sh ] && . ${i}/utils.sh
done

if [ -z "$STATE_OK" ];then
   echo "nagios utils.sh not found" &>/dev/stderr
   exit 1
fi

-----------------------------------------------------------------


# --------------------------------------------------------------------
# functions
# --------------------------------------------------------------------
function log() {
    $LOGGER ${PROGNAME} "$@";
}

function usage() {
    echo "Usage: $PROGNAME --uid=<effective uid> --gid=<effective gid> --username=<username> --group=<groupname> [--suppgroup=\"<supplementary groups>\"]"
    echo "Usage: $PROGNAME -h,--help"
}

function print_help() {
    echo ""
    usage
    echo "Check if a specified user exists and that he has the correct userId, groupId"
    echo "and supplementary groups."
    echo ""
    echo "Options: (needed)"
    echo " --uid=<effective uid>  UserID to match with user"
    echo " --gid=<effective gid>  GroupID to match with maingroup of user"
    echo " --username=<username>  Username"
    echo " --group=<groupname>    Name of primary group of the user"
    echo ""
    echo "Options: (optional)"
    echo " --suppgroup=\"<supplementary groups>\""
    echo "     supplementary groups to match for given user. seperate by comma"
    echo ""
    echo "States:"
    echo "  Returns OK: if user exists and has correct uid,gid and supplementary groups"
    echo "  Returns WARNING: never"
    echo "  Returns CRITICAL: if one or more of the given parameters dont match"
    echo ""
    echo "This plugin is NOT developped by the Nagios Plugin group."
    echo "Please do not e-mail them for support on this plugin, since"
    echo "they won't know what you're talking about."
    echo ""
    echo "For contact info, read the plugin itself..."
}

# --------------------------------------------------------------------
# startup checks
# --------------------------------------------------------------------

case "$1" in
	--help) print_help; exit $STATE_OK;;
	-h) print_help; exit $STATE_OK;;
	*) if [ $# -lt 4 ]; then usage; exit $STATE_CRITICAL; fi;;
esac

getopt_simple()
{
	until [ -z "$1" ]; do
		if [ ${1:0:2} = '--' ]; then ## wenn $1 mit -- beginnt
			tmp=${1:2}               # Strip off leading '/' . . .
			parameter=${tmp%%=*}     # Extract name.
			value=${tmp##*=}         # Extract value.
			eval $parameter=$value
		fi
		shift
	done
}

# Pass all options to getopt_simple().
getopt_simple $*
ARR_ERROR=()

TMP_VAL=$(id -u $username 2>/dev/null); RET_VAL=$?
if [ $RET_VAL -eq 0 ]; then
	## $username exists
	## check uid
	if [ "$TMP_VAL" -ne "$uid" ]; then
		ARR_ERROR[${#ARR_ERROR[@]}]="$TMP_VAL is not expected uid ($uid) for user $username"
	fi
	# check group
	TMP_VAL=$(id -ng $username)
	if [ $TMP_VAL != $group ]; then
		ARR_ERROR[${#ARR_ERROR[@]}]="$TMP_VAL is not expected group ($group) for user $username"
	else
	        # check supplementary groups
	        if [ $suppgroup ]; then
	                ## replace all "'" in suppgroup
	                suppgroup=${suppgroup//','/ }
	                ## sort suppgroup
	                suppgroup=$(echo $suppgroup| tr ' ' '\n' | sort | tr '\n' ' ')
	                ## strip last char from suppgroup
	                suppgroup=${suppgroup:0:${#suppgroup}-1}
	                TMP_VAR=$(id -nG $username)
	                COMPARE_VAR="$group $suppgroup"
	                if [ "$TMP_VAR" != "$COMPARE_VAR" ];then
	                        ARR_ERROR[${#ARR_ERROR[@]}]="$TMP_VAR is not expected suppgroup ($COMPARE_VAR) for user $username"
	                fi
	        fi
	fi
	# check gid
	TMP_VAL=$(id -g $username)
	if [ $TMP_VAL -ne $gid ]; then
		ARR_ERROR[${#ARR_ERROR[@]}]="$TMP_VAL is not expected gid ($gid) for user $username"
	fi
else
	ARR_ERROR[${#ARR_ERROR[@]}]="$username is not valid user on $HOSTNAME"
fi
if [ ${#ARR_ERROR[@]} -gt 0 ]; then
	for element in $(seq 0 $(expr ${#ARR_ERROR[@]} - 1)); do
		echo "CRITICAL: "${ARR_ERROR[$element]}
	done
	exit $STATE_CRITICAL
fi

echo "OK: user $(id $username)"
exit $STATE_OK
