#!/bin/bash

# this is an installation script for usb_kb_layout, 
# so we put files on their proper places
# https://github.com/felipeheuer/usb_kb_layout

while true; do
    # Function to display the list of devices
    display_device_list() {
        clear
        # Display installer title
        echo "USB Keyboard Layout Installer"
        echo "-----------------------------"
        for i in "${!devices_array[@]}"; do
            if [[ "$i" -eq "$position" ]]; then
                echo -n "> "
            else
                echo -n "    "
            fi
            echo "${devices_array[$i]}"
        done
    }

    # Get the list of keyboard devices from xinput and save to an array
    xinput_output=$(xinput -list | grep "keyboard" | grep -v "Virtual core" | sed -E 's/\s+id=[0-9]+.*$//' | sed -E 's/^\s*([⎜↳]\s*)*//' | sort -u)

    # Remove newline characters from the end of each array element
    mapfile -t devices_array <<< "$xinput_output"

    # Remove carriage return and newline characters from each array element
    for i in "${!devices_array[@]}"; do
        devices_array[$i]=$(echo "${devices_array[$i]}" | sed 's/\r$//;s/\n$//')
    done

    # Filter xinput devices based on lsusb output
    filtered_devices_array=()
    for device in "${devices_array[@]}"; do
        if lsusb | grep -q "$device"; then
            filtered_devices_array+=("$device")
        fi
    done
    devices_array=("${filtered_devices_array[@]}")

    # Initialization
    position=0
    list_size=${#devices_array[@]}

    # Main loop (device selection)
    stty -icanon -echo
    while true; do
        display_device_list

        # Read user input
        read -s -N 1 key

        if [[ "$key" == $'\e' ]]; then
            read -n 2 key2
            if [[ "$key2" == '[A' ]]; then # Up arrow
                if [[ "$position" -gt 0 ]]; then
                    position=$((position - 1))
                fi
            elif [[ "$key2" == '[B' ]]; then # Down arrow
                if [[ "$position" -lt $((list_size - 1)) ]]; then
                    position=$((position + 1))
                fi
            fi
        elif [[ "$key" == $'\x0a' ]] || [[ "$key" == $'\r' ]]; then # Enter
            break
        elif [[ "$key" == "q" ]]; then # Quit
            stty icanon echo
            exit 0
        fi
    done
    stty icanon echo

    selected_device="${devices_array[$position]}"

    # Search for the selected device in lsusb output
    lsusb_output=$(lsusb | grep "$selected_device")

    # Display the found line and ask for confirmation
    if [[ -n "$lsusb_output" ]]; then
        idVendor=$(echo "$lsusb_output" | awk '{print $6}' | cut -d ':' -f 1)
        idProduct=$(echo "$lsusb_output" | awk '{print $6}' | cut -d ':' -f 2)
    else
        echo "Device not found in lsusb. Restarting process..."
        continue
    fi

    # Ask the user for keyboard layout and variant
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

    # Create a string with keyboard options
    keyboard_options="-layout $layout"

    # Add variant to the string, if provided
    if [[ -n "$variant" ]]; then
        keyboard_options="$keyboard_options -variant $variant"
    fi

    # Ask the user for the installation directory
    read -p "Enter installation directory (default: /opt/usb_kb_layout/): " installation_dir
    if [[ -z "$installation_dir" ]]; then
        installation_dir="/opt/usb_kb_layout/"
    fi

    # Ask the user for the script owner
    read -p "Enter script owner (default: $(whoami)): " script_owner
    if [[ -z "$script_owner" ]]; then
        script_owner=$(whoami)
    fi

    # Display keyboard options
    echo "Selected device: $selected_device (idVendor: $idVendor, idProduct: $idProduct)"
    echo "Keyboard options: $keyboard_options"
    echo "Installation path: $installation_dir"
    echo "Script owner: $script_owner"

    # Ask the user to confirm the options
    echo -n "Are the above options correct? (y/n): "
    while true; do
        read -s -N 1 confirmation
        if [[ "$confirmation" == "y" || "$confirmation" == "n" ]]; then
            break
        fi
    done

    # Verify user confirmation
    if [[ "$confirmation" == "y" ]]; then
        echo ""
        echo "Options confirmed. Continuing installation..."
        break # Exit the main loop if options are confirmed
    else
        echo ""
        echo "Options incorrect. Restarting process..."
    fi
done

# Create installation directory and copy files
sudo mkdir -p "$installation_dir"
sudo chmod 755 "$installation_dir"

for file in usb_kb_layout*.sh; do
    sudo cp "$file" "$installation_dir"
    sudo chmod 755 "$installation_dir/$file"
done

# Edit usb_kb_layout_wrapper.sh
sudo sed -i 's|.*\.sh.*|'"$installation_dir"'/usb_kb_layout.sh \&|' "$installation_dir/usb_kb_layout_wrapper.sh"

# Edit usb_kb_layout.sh with the obtained values
escaped_keyboard_options=$(printf "%s" "$keyboard_options" | sed 's/-/\\-/g')
sudo sed -i "0,/^kb_model_usb=/s/^kb_model_usb=\".*\"/kb_model_usb=\"$selected_device\"/" "$installation_dir/usb_kb_layout.sh"
sudo sed -i "0,/^kb_layout_usb=/s/^kb_layout_usb=\".*\"/kb_layout_usb=\"$escaped_keyboard_options\"/" "$installation_dir/usb_kb_layout.sh"
sudo sed -i "0,/^user_name=/s/^user_name=\".*\"/user_name=\"$script_owner\"/" "$installation_dir/usb_kb_layout.sh"

# Copy and edit 99-usb-keyboard.rules file
sudo cp 99-usb-keyboard.rules /etc/udev/rules.d/
sudo chmod 644 /etc/udev/rules.d/99-usb-keyboard.rules
sudo sed -i 's/OWNER="[^"]*"/OWNER="'"$script_owner"'"/' /etc/udev/rules.d/99-usb-keyboard.rules
sudo sed -i 's|RUN+=".*\/usb_kb_layout_wrapper.sh"|RUN+="'"$installation_dir"'/usb_kb_layout_wrapper.sh"|' /etc/udev/rules.d/99-usb-keyboard.rules

# Reload udev rules
sudo udevadm control --reload-rules

exit 0
