#!/bin/bash

# this script sets a new layout for the selected keyboard
# gitlab.com/felipeheuer

# !!! update the following lines with your keyboard and user information
kb_model_usb="Vulcan Pro TKL"
kb_layout_usb="-layout de -variant legacy"
user_name="username"

# !!! no need to update bellow this line

log_enable=1
log_file=/var/log/usb_kb_layout.log
script_file=$(basename "${BASH_SOURCE[0]}")
update_laptop_kb=1

function log() {
    if [ $log_enable -eq 1 ]; then
        echo "$(date) $1" >> "$log_file"
    fi
}

function get_kb_id() {
    xinput -list | grep "keyboard" | grep "${1}"| grep -v "Control" | sed -n "s/.*id=\([0-9]*\).*/\1/p" | sort -nr
}

# ------ script start ------
for pid in $(pidof -x "${script_file}"); do
    if [ $pid != $$ ]; then
        # stop the script if it's already running
        exit 1
    fi
done

log "Start"
kb_model="Virtual core keyboard"
kb_layout="-layout us -variant intl"

DISPLAY=":0.0"
HOME=/home/$user_name
XAUTHORITY=$HOME/.Xauthority
export DISPLAY XAUTHORITY HOME

sleep 1s

usbkbd_id=$(get_kb_id "$kb_model_usb")
if [ "${usbkbd_id}" ]; then
    if [ $update_laptop_kb -eq 1 ]; then
        kb_laptop_id=$(get_kb_id "$kb_model")
        setxkbmap -verbose -device $kb_laptop_id $kb_layout
        log "${kb_model} updated with '${kb_layout}', id: $kb_laptop_id"
    fi

    for kb_id in $usbkbd_id; do
        if [ "${kb_id}" ]; then
            setxkbmap -verbose -device $kb_id $kb_layout_usb
            log "${kb_model_usb} updated with '${kb_layout_usb}', id: $kb_id"
        fi
    done
fi
log "Done"

exit 0
