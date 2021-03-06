#!/bin/sh
# -*- mode: Shell-script; -*-

rossetdefault() {
    local hostname=${1-"local"}
    local ros_port=${2-"11311"}
    if [ "$ROS_HOME" != "" ]; then
        local ros_home=$ROS_HOME
    else
        local ros_home="$HOME/.ros"
    fi
    mkdir -p $ros_home/jsk_tools
    echo -e "$hostname\n$ros_port" > $ros_home/jsk_tools/rosdefault
    rosdefault
}
rosdefault() {
    if [ "$ROS_HOME" != "" ]; then
        local ros_home=$ROS_HOME
    else
        local ros_home="$HOME/.ros"
    fi
    if [ -f $ros_home/jsk_tools/rosdefault ]; then
        local hostname="$(sed -n 1p $ros_home/jsk_tools/rosdefault)"
        local ros_port="$(sed -n 2p $ros_home/jsk_tools/rosdefault)"
    else
        local hostname="local"
        local ros_port="11311"
    fi
    if [ "$hostname" = "local" ]; then
        rossetlocal $ros_port
    else
        rossetmaster $hostname $ros_port
    fi
}

_update_prompt() {
    local master_host=$(echo $ROS_MASTER_URI | cut -d\/ -f3 | cut -d\: -f1)
    if [ "$master_host" = "localhost" ]; then
        if echo $PS1 | grep "\[http://.*\]" > /dev/null
        then
            export PS1="${WITHOUT_ROS_PROMPT}"
        fi
    elif [ "$master_host" != "" ]; then
        local ros_prompt="[$ROS_MASTER_URI][$ROS_IP]"
        if [ "$CATKIN_SHELL" = "bash" ]; then
            export PS1="\[\033[00;31m\]$ros_prompt\[\033[00m\] ${WITHOUT_ROS_PROMPT}"
        elif [ "$CATKIN_SHELL" = "zsh" ]; then
            export PS1="%{$fg[red]%}$ros_prompt%{$reset_color%} ${WITHOUT_ROS_PROMPT}"
        else
            echo "unsupported shell"
        fi
    fi
}

rossetmaster() {
    if [ "${WITHOUT_ROS_PROMPT}" = "" ]; then
        export WITHOUT_ROS_PROMPT="$PS1"
    fi
    local hostname=${1-"pr1040"}
    local ros_port=${2-"11311"}
    export ROS_MASTER_URI=http://$hostname:$ros_port
    if [ "$NO_ROS_PROMPT" = "" ]; then
        _update_prompt
    fi
    echo -e "\e[1;31mset ROS_MASTER_URI to $ROS_MASTER_URI\e[m"
}
rossetrobot() {
    echo -e "\e[1;31m *** rossetrobot is obsoleted, use rossetmaster ***\e[m"
    rossetmaster $@
}

rossetlocal() {
    local ros_port=${1-"11311"}
    rossetmaster localhost $ros_port
    if [ "$NO_ROS_PROMPT" = "" ]; then
        _update_prompt
    fi
}

rossetip_dev() {
    local device=${1-"(eth0|eth1|eth2|eth3|eth4|wlan0|wlan1|wlan2|wlan3|wlan4)"}
    export ROS_IP=`PATH=$PATH:/sbin LANGUAGE=en LANG=C ifconfig | egrep -A1 "${device}"| grep inet\  | grep -v 127.0.0.1 | sed 's/.*inet addr:\([0-9\.]*\).*/\1/' | head -1`
    export ROS_HOSTNAME=$ROS_IP
}

rossetip_addr() {
    local target_host=${1-"133.11.216.211"}
    ##target_hostip=$(host ${target_host} | sed -n -e 's/.*address \(.*\)/\1/gp')
    # Check if target_host looks like ip address or not
    if [ "$(echo $target_host | sed -e 's/[0-9\.]//g')" != "" ]; then
        target_hostip=$(timeout 0.001 getent hosts ${target_host} | cut -f 1 -d ' ')
    fi
    if [ "$target_hostip" = "" ]; then target_hostip=$target_host; fi
    local mask_target_ip=$(echo ${target_hostip} | cut -d. -f1-3)
    export ROS_IP=$(PATH=$PATH:/sbin LANGUAGE=en LANG=C ifconfig | grep inet\ | sed 's/.*inet addr:\([0-9\.]*\).*/\1/' | tr ' ' '\n' | grep $mask_target_ip | head -1)
    export ROS_HOSTNAME=$ROS_IP
}

rossetip() {
    local device=${1-"(eth0|eth1|eth2|eth3|eth4|wlan0|wlan1|wlan2|wlan3|wlan4)"}
    if [[ $device =~ [0-9]+.[0-9]+.[0-9]+.[0-9]+ ]]; then
        export ROS_IP="$device"
    else
        export ROS_IP=""
        local master_host=$(echo $ROS_MASTER_URI | cut -d\/ -f3 | cut -d\: -f1)
        if [ "${master_host}" != "localhost" ]; then rossetip_addr ${master_host} ; fi
        if [ "${ROS_IP}" = "" ]; then rossetip_dev ${device}; fi
    fi
    export ROS_HOSTNAME=$ROS_IP
    if [ "${ROS_IP}" = "" ];
    then
        unset ROS_IP
        unset ROS_HOSTNAME
        echo -e "\e[1;31munable to set ROS_IP and ROS_HOSTNAME\e[m"
        return 1
    else
        echo -e "\e[1;31mset ROS_IP and ROS_HOSTNAME to $ROS_IP\e[m"
    fi
    if [ "$NO_ROS_PROMPT" = "" ]; then
        _update_prompt
    fi
}

rosn() {
    which percol || echo -e "\e[1;31mNeed to install percol, \`sudo pip install python-percol\` or \`rosdep install jsk_tools\` \e[m";
    which percol || return 1
    if [ "$1" = "" ]; then
        topic=$(rosnode list | percol | xargs -n 1 rosnode info | percol | sed -e 's%.* \* \(/[/a-zA-Z0-9_]*\) .*%\1%')
    else
        topic=$(rosnode info $1 | percol | sed -e 's%.* \* \(/[/a-zA-Z0-9_]*\) .*%\1%')
    fi
    if [ "$topic" != "" ] ; then
        rost $topic
    fi
}
rost() {
    which percol || echo -e "\e[1;31mNeed to install percol, \`sudo pip install python-percol\` or \`rosdep install jsk_tools\` \e[m";
    which percol || return 1
    if [ "$1" = "" ]; then
        node=$(rostopic list | percol | xargs -n 1 rostopic info | percol | sed -e 's%.* \* \(/[/a-zA-Z0-9_]*\) .*%\1%')
    else
        node=$(rostopic info $1 | percol | sed -e 's%.* \* \(/[/a-zA-Z0-9_]*\) .*%\1%')
    fi
    if [ "$node" != "" ] ; then
        rosn $node
    fi
}
