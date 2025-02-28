#!/bin/bash

# Initial configurations
set -euo pipefail

# Global variables
position=0
devices_array=()
installation_dir="/opt/usb_kb_layout/"
script_owner=$(whoami)

# Display functions
display_title() {
    echo "USB Keyboard Layout Installer"
    echo "-----------------------------"
    echo " "
    echo "Select your keyboard from the list:"
}

display_device_list() {
    clear
    display_title
    local i
    for i in "${!devices_array[@]}"; do
        if [[ "$i" -eq "$position" ]]; then
            echo -n "> "
        else
            echo -n "    "
        fi
        echo "${devices_array[$i]}"
    done
}

# Device selection functions
get_keyboard_devices() {
    local xinput_output
    xinput_output=$(xinput -list | grep "keyboard" | grep -v "Virtual core" | sed -E 's/\s+id=[0-9]+.*$//' | sed -E 's/^\s*([⎜↳]\s*)*//' | sort -u)
    mapfile -t devices_array <<< "$xinput_output"
    local i
    for i in "${!devices_array[@]}"; do
        devices_array[$i]=$(echo "${devices_array[$i]}" | sed 's/\r$//;s/\n$//')
    done
}

filter_usb_devices() {
    local filtered_devices_array=()
    local device
    for device in "${devices_array[@]}"; do
        if lsusb | grep -q "$device"; then
            filtered_devices_array+=("$device")
        fi
    done
    devices_array=("${filtered_devices_array[@]}")
}

select_device() {
    local list_size=${#devices_array[@]}
    stty -icanon -echo
    while true; do
        display_device_list
        read -s -N 1 key
        if [[ "$key" == $'\e' ]]; then
            read -n 2 key2
            if [[ "$key2" == '[A' && "$position" -gt 0 ]]; then
                position=$((position - 1))
            elif [[ "$key2" == '[B' && "$position" -lt $((list_size - 1)) ]]; then
                position=$((position + 1))
            fi
        elif [[ "$key" == $'\x0a' || "$key" == $'\r' ]]; then
            break
        elif [[ "$key" == "q" ]]; then
            stty icanon echo
            exit 0
        fi
    done
    stty icanon echo
    echo ""
    echo "Selected device: ${devices_array[$position]}"
    return 0
}

get_device_ids() {
    local lsusb_output
    lsusb_output=$(lsusb | grep "${devices_array[$position]}")
    if [[ -n "$lsusb_output" ]]; then
        idVendor=$(echo "$lsusb_output" | awk '{print $6}' | cut -d ':' -f 1)
        idProduct=$(echo "$lsusb_output" | awk '{print $6}' | cut -d ':' -f 2)
        return 0
    else
        echo "Device not found in lsusb. Restarting process..."
        return 1
    fi
}

# Layout configuration functions
get_keyboard_layout() {
    while true; do
        read -e -p "Enter keyboard layout (e.g., us, de, at): " layout
        if [[ -n "$layout" ]]; then
            break
        else
            tput cuu1
            tput el
        fi
    done
    read -p "Enter keyboard variant (optional): " variant
    keyboard_options="-layout $layout"
    if [[ -n "$variant" ]]; then
        keyboard_options="$keyboard_options -variant $variant"
    fi
}

# Installation functions
get_installation_dir() {
    read -p "Enter installation directory (default: /opt/usb_kb_layout/): " installation_dir
    if [[ -z "$installation_dir" ]]; then
        installation_dir="/opt/usb_kb_layout/"
    fi
    installation_dir="${installation_dir%/}"
}

get_script_owner() {
    read -p "Enter script owner (default: $(whoami)): " script_owner
    if [[ -z "$script_owner" ]]; then
        script_owner=$(whoami)
    fi
}

display_user_options() {
    echo "Selected device: ${devices_array[$position]} (idVendor: $idVendor, idProduct: $idProduct)"
    echo "Keyboard options: $keyboard_options"
    echo "Installation path: $installation_dir"
    echo "Script owner: $script_owner"
}

confirm_options() {
    echo -n "Are the above options correct? (y/n): "
    while true; do
        read -s -N 1 confirmation
        if [[ "$confirmation" == "y" || "$confirmation" == "n" ]]; then
            echo ""
            return 0
        fi
    done
}

install_scripts() {
    sudo mkdir -p "$installation_dir"
    sudo chmod 755 "$installation_dir"
    for file in usb_kb_layout*.sh; do
        sudo cp "$file" "$installation_dir"
        sudo chmod 755 "$installation_dir/$file"
    done
}

configure_scripts() {
    local escaped_keyboard_options=$(printf "%s" "$keyboard_options" | sed 's/-/\\-/g')
    sudo sed -i "0,/^kb_model_usb=/s/^kb_model_usb=\".*\"/kb_model_usb=\"${devices_array[$position]}\"/" "$installation_dir/usb_kb_layout.sh"
    sudo sed -i '0,/^kb_layout_usb=/s/^kb_layout_usb=\".*\"/kb_layout_usb="'"$escaped_keyboard_options"'"/' "$installation_dir/usb_kb_layout.sh"
    sudo sed -i "0,/^user_name=/s/^user_name=\".*\"/user_name=\"$script_owner\"/" "$installation_dir/usb_kb_layout.sh"
}

configure_udev_rules() {
    sudo cp 99-usb-keyboard.rules /etc/udev/rules.d/
    sudo chmod 644 /etc/udev/rules.d/99-usb-keyboard.rules
    sudo sed -i 's|OWNER="[^"]*"|OWNER="'"$script_owner"'"|' /etc/udev/rules.d/99-usb-keyboard.rules
    sudo sed -i "s|RUN+=\".*\/usb_kb_layout_wrapper.sh\"|RUN+=\"$installation_dir\/usb_kb_layout_wrapper.sh\"|" /etc/udev/rules.d/99-usb-keyboard.rules
}

configure_wrapper() {
    sudo sed -i "s|.*\.sh.*|${installation_dir}/usb_kb_layout.sh \&|" "$installation_dir/usb_kb_layout_wrapper.sh"
}

reload_udev_rules() {
    sudo udevadm control --reload-rules
}

# Main flow
echo "Make sure your desired keyboard is plugged in."
echo "Press Enter to continue, or Q to quit."
read -s -n 1 key
if [[ "$key" == "q" ]]; then
    exit 0
fi

while true; do
    get_keyboard_devices
    filter_usb_devices
    if select_device; then
        if get_device_ids; then
            get_keyboard_layout
            get_installation_dir
            get_script_owner
            display_user_options
            if confirm_options; then
                install_scripts
                configure_wrapper
                configure_scripts
                configure_udev_rules
                reload_udev_rules
                echo "Installation completed successfully."
                break
            else
                echo "Options incorrect. Restarting process..."
            fi
        fi
    fi
done

exit 0