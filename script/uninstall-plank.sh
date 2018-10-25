#!/bin/bash

if ! [ "$UID" -eq 0 ]
then
    echo "You must run this script as root (sudo script/uninstall-plank.sh)"
    exit
fi

INSTALL_PATH="/usr/local"

rm -rf `find $INSTALL_PATH -name plank` `find $INSTALL_PATH -name plank.*` `find $INSTALL_PATH -name libplank*`
echo "Plank successfully uninstalled"