#!/bin/bash

if [ "$1" = "0" ]; then
    # Package removal
    systemctl stop dedup-service
    systemctl disable dedup-service
    
    # Remove user and group if no other packages use them
    if getent passwd dedup >/dev/null; then
        userdel dedup
    fi
    
    if getent group dedup >/dev/null; then
        groupdel dedup
    fi
fi
