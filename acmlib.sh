# Active Coutermeasures Script Library
# This library contains commonly used helper functions.

#### User Interface

askYN () {
    # Prints a question mark, reads repeatedly until the user
    # repsonds with t/T/y/Y or f/F/n/N.
	TESTYN=""
	while [ "$TESTYN" != 'Y' ] && [ "$TESTYN" != 'N' ] ; do
		echo -n '? ' >&2
		read -e TESTYN <&2 || :
		case $TESTYN in
		T*|t*|Y*|y*)		TESTYN='Y'	;;
		F*|f*|N*|n*)		TESTYN='N'	;;
		esac
	done

	if [ "$TESTYN" = 'Y' ]; then
		return 0 #True
	else
		return 1 #False
	fi
}

fail () {
    # Displays the passed in error and asks the user if they'd like to continue
    # the script. Will exit with error code 1 if the user stops the script.
	echo "$*" >&2
	echo "This is normally an unrecoverable problem, and we recommend fixing the problem and restarting the script. Please contact technical support for help in resolving the issue. If you feel the script should continue, enter   Y   and the script will attempt to finish. Entering   N    will cause this script to exit." >&2
	if askYN ; then
		echo "Script will continue at user request. This may not result in a working configuration." >&2
		sleep 5
	else
		exit 1
	fi
}

prompt2 () {
    # echo's the input to stderr, does not put a newline after the text
    echo -n "$*" >&2
}

echo2 () {
    # echo's the input to file descriptor 2 (stderr)
    echo "$*" >&2
}


status () {
    echo2 ""
	echo2 "================ $* ================"
	# DEBUG AID: Uncomment the lines below to enable pausing the install script
    # at each status marker
    #echo2 "Press enter to continue"
	#read -e JUNK <&2
}

#### Environment Variables

normalize_environment () {
    # Normalizes environment variables across different
    # environments.

    # Normalize the home directory. Sudo set's $HOME to /root
    # on CentOS 7
    if [ "$HOME" = "/root" -a -n "$SUDO_USER" -a "$SUDO_USER" != "root" ]; then
        export HOME="/home/$SUDO_USER/"
    fi
}

#### SSH Utilities

check_ssh_target_is_local () {
    # Returns whether a ssh target is set to a remote system
    [ -n "$1" ] && [[ "$1" =~ .*127.0.0.1$ ]]
}

check_ssh_target_is_remote () {
    # Returns whether a ssh target is set to a remote system
    [ -n "$1" ] && [[ ! "$1" =~ .*127.0.0.1$ ]]
}

can_ssh () {
    # Tests that we can reach a target system over ssh.
    # $1 must be the target, the following arguments are supplied to ssh
    if [ -z "$1" ]; then
        # Target is empty
        return 1
    fi

    local token="$RANDOM.$RANDOM"
    echo2 "Verifying that we can ssh to $1 - you may need to provide a password to access this system."
    ssh_out=`ssh "$@" '/bin/echo '"$token"`
    if [ "$token" = "$ssh_out" ]; then
        # SSH successful
        return 0
    fi
    return 1
}

master_ssh() {
    #Creates a master ssh session/ socket which other connections
    #can piggyback off of. You must use the ssh flags returned by `get_master_ssh_flags`
    #in order to use the master socket.
    mkdir -p ~/.ssh/sockets/
    if ssh -o 'ControlPath=~/.ssh/sockets/master-%r@%h:%p' -O check "$@" >/dev/null 2>&1 ; then
    #If the master is currently running kill it so the socket is available for use.
        kill_master_ssh "$@"
	fi
	ssh -o 'ControlPath=~/.ssh/sockets/master-%r@%h:%p' -o 'ControlMaster=yes' -o 'ControlPersist=7200' -f "$@" 'sleep 7200'
}

kill_master_ssh () {
    #Kills a persistent ssh socket and all associated connections
	#Note that this kills not only the master but also any remaining client connections as well.
	ssh -o 'ControlPath=~/.ssh/sockets/master-%r@%h:%p' -O 'exit' "$@" >/dev/null 2>&1
}

get_master_ssh_flags () {
    #Returns the flags needed to piggyback a ssh connection off of a
    #master socket as created by `master_ssh`
    echo '-o ControlPath=~/.ssh/sockets/master-%r@%h:%p -o ControlMaster=no'
}

#### BASH Arrays

elementIn () {
    # Searches for the first argument in the rest of the arguments
    # array=("something to search for" "a string" "test2000")
    # containsElement "a string" "${array[@]}"
    local e match="$1"
    shift
    for e; do [[ "$e" = "$match" ]] && return 0; done
    return 1
}

caseInsensitiveElementIn () {
    # Searches for the first argument in the rest of the arguments
    # using a case insenstive comparison.
    local e match="${1,,}"
    shift
    for e; do [[ "${e,,}" = "$match" ]] && return 0; done
    return 1
}

#### System Tests

require_file () {
    #Stops the script if any of the files or directories listed do not exist.

	while [ -n "$1" ]; do
		if [ ! -e "$1" ]; then
			fail "Missing object $1. Please install it."
		fi
		shift
	done
	return 0							#True, all objects are here
}

require_sse4_2 () {
    #Stops the script is sse4_2 is not supported on the local system

    require_file /proc/cpuinfo  || fail "Missing /proc/cpuinfo - is this a Linux system?"
    if ! grep -q '^flags.*sse4_2' /proc/cpuinfo ; then
        fail 'This processor does not have SSE4.2 support needed for AI Hunter'
    fi
    return 0
}

require_free_space() {
        # An array of directories consisting of all but the last function argument
	local dirs="${*%${!#}}"
        # The number of megabytes to check for is in the last function argument
	local mb="${@:$#}"

	# Check for free space:
	for one_dir in $dirs; do
		[ $(df "$one_dir" -P -BM 2>/dev/null | grep -v 'Avail' | awk '{print $4}' | tr -dc '[0-9]') -ge $mb ] || fail "$one_dir has less than ${mb}MB of free space!"
		echo2 "$one_dir has at least ${mb}MB of free space, good."
	done

	return 0
}

check_os_is_centos () {
    [ -s /etc/redhat-release ] && grep -iq 'release 7' /etc/redhat-release
}

check_os_is_ubuntu () {
    grep -iq '^DISTRIB_ID *= *Ubuntu' /etc/lsb-release
}

require_supported_os () {
    #Stops the script if the OS is not supported

    #TODO: Test for minimum kernel version
    if check_os_is_centos ; then
		echo2 "CentOS or Redhat 7 installation detected, good."
	elif check_os_is_ubuntu ; then
		echo2 "Ubuntu installation detected, good."
	else
		fail "This system does not appear to be a CentOS/ RHEL 7 or Ubuntu system"
	fi
    return 0
}

require_util () {
    #Stops the script is any binary listed does not exist somewhere in the PATH.

    while [ -n "$1" ]; do
        if ! type -path "$1" >/dev/null 2>/dev/null ; then
            fail "Missing utility $1. Please install it."
        fi
        shift
    done
    return 0
}

require_sudo () {
    #Stops the script if the user does not have root priviledges and cannot sudo
    #Additionally, sets $SUDO to "sudo" and $SUDO_E to "sudo -E" if needed.

    if [ "$EUID" -eq 0 ]; then
        SUDO=""
        SUDO_E=""
        return 0
    fi

    if sudo -v; then
        SUDO="sudo"
        SUDO_E="sudo -E"
        return 0
    fi
    fail 'Missing administrator priviledges. Please run with an account with sudo privilidges.'
}

require_executable_tmp_dir () {
    NEWTMP="$HOME/.tmp"
    if [ -n "$TMPDIR" ] && findmnt -n -o options -T "$TMPDIR" | grep -qvE '(^|,)noexec($|,)' ; then
        : # we have an executable tmpdir. Good.
    elif [ -d "/tmp" ] && findmnt -n -o options -T "/tmp" | grep -qvE '(^|,)noexec($|,)' ; then
        export TMPDIR="/tmp"
    else
        mkdir -p "$NEWTMP"
        if findmnt -n -o options -T "$NEWTMP" | grep -qE '(^|,)noexec($|,)' ; then
            fail 'Could not create a temporary directory in an executable volume. Set your TMPDIR environment variable to a directory on an executable volume and retry.'
        fi
        export TMPDIR="$(realpath "$NEWTMP")"
    fi
    return 0
}


can_write_or_create () {
    # Checks if the current user has permission to write to the provided file or directory.
    # If it doesn't exist then it recursively checks if the file and all parent directories
    # can be created.

    local file="$1"

    if [ ! -e "$file" ]; then
        # if the file doesn't exist then return whether or not we can write to the parent directory
        can_write_or_create "$(dirname "$file")"
    elif [ -w "$file" ]; then
        # if the file exists and is writable return true
        true
    else
        # otherwise we know the file doesn't exist and is not writable with the current user
        false
    fi
}

ensure_common_tools_installed () {
    #Installs common tools used by acm scripts. Supports yum and apt-get.
    #Stops the script if neither apt-get nor yum exist.

    require_sudo

    local ubuntu_tools="gdb git wget curl make netcat realpath lsb-release rsync tar"
    local centos_tools="gdb git wget curl make nmap-ncat coreutils iproute redhat-lsb-core rsync tar"
    local required_tools="adduser awk cat chmod chown cp curl date egrep gdb getent git grep ip lsb_release make mkdir mv nc passwd printf rm rsync sed ssh-keygen sleep tar tee tr wc wget"
    if [ -x /usr/bin/apt-get -a -x /usr/bin/dpkg-query ]; then
        #We have apt-get, good.

	#Check Ubuntu version, adjust package list for 18.04

	# Source os-release to avoid using lsb_release.
	# Relevant variable is $VERSION_CODENAME.
	. /etc/os-release
	if [ "$VERSION_CODENAME" = "bionic" ]; then
		# can also be done with `ubuntu_tools="${ubuntu_tools/realpath/coreutils}"`
		ubuntu_tools="gdb git wget curl make netcat coreutils lsb-release rsync tar"
	fi

        $SUDO apt-get -qq update > /dev/null 2>&1
		while ! $SUDO apt-get -qq install $ubuntu_tools ; do
            echo2 "Error installing packages, perhaps because a system update is running; will wait 60 seconds and try again."
            sleep 60
		done
    elif [ -x /usr/bin/yum -a -x /bin/rpm ]; then
        #We have yum, good.

        #Make sure we have yum-config-manager. It might be in yum-utils.
        if [ ! -x /bin/yum-config-manager ]; then
			$SUDO yum -y -q -e 0 install yum-utils
		fi

        $SUDO yum -q -e 0 makecache > /dev/null 2>&1
        #Yum takes care of the lock loop for us
        $SUDO yum -y -q -e 0 install $centos_tools
    else
        fail "Neither (apt-get and dpkg-query) nor (yum, rpm, and yum-config-manager) is installed on the system"
    fi

    require_util $required_tools
    return 0
}
