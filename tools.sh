#!/bin/bash

b="\x1b[34m"
y="\x1b[93m"
g="\x1b[32m"
w="\x1b[37m"
r="\x1b[31m"
reset="\x1b[0m"

debug=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--debug)
            debug=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ "$debug" == true ]; then
    set -x
fi
if [[ $# -lt 1 ]]; then
    echo -e " ${r}●${w} No command provided."
    exit 1
fi

command="$1"
shift

echo -e " _____ _                 _         _       _    _____         _     \n|  _  | |_ ___ ___ ___ _| |___ ___| |_ _ _| |  |_   _|___ ___| |___ \n|   __|  _| -_|  _| . | . | .'|  _|  _| | | |    | | | . | . | |_ -|\n|__|  |_| |___|_| |___|___|__,|___|_| |_  |_|    |_| |___|___|_|___|\n                                      |___|                          "


case "$command" in
    backup)
        curl -sL "https://raw.githubusercontent.com/david1117dev/pterodactyl-tools/refs/heads/main/backup.sh" -o /tmp/backup.sh && chmod +x /tmp/backup.sh && source /tmp/backup.sh "$@"
        ;;
    *)
        echo -e " ${r}●${w} Unknown command: $command"
        exit 1
        ;;
esac

if [ "$debug" == true ]; then
    set +x
fi
