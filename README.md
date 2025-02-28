# usb_kb_layout
Scripts to update an external USB keybaord's layout when it is plugged in.

## Installation
### Automatic
Make sure the `install.sh` script has run permision, run it and follow the instructions on the terminal.

### Manual
- Edit `usb_kb_layout.sh` and update it according to your desired layout. Copy both `usb_kb_layout.sh` and `usb_kb_layout_wrapper.sh` to `/opt/usb_kb_layout/` folder. Give the folder root run access recursively.
- Edit `99-usb-keyboard.rules` and change values for the parameters `ATTRS{idVendor}`, `ATTRS{idProduct}` and `OWNER` to match your needs. Copy the updated file to `/etc/udev/rules.d` and give it root run access.
- Run `sudo udevadm control --reload-rules` so udev can see the new rule added.
- Create the log file running `sudo touch /var/log/usb_kb_layout.log`

## Testing
Connect (or re-connect) your USB keyboard, wait a couple of seconds and check the content of the log file, You should see something similar to:

    Fri Feb 28 10:34:13 CET 2025 Start
    Fri Feb 28 11:18:16 CET 2025 Virtual core keyboard updated with '-layout us -variant intl', id: 3
    Fri Feb 28 11:18:16 CET 2025 Vulcan Pro TKL updated with '-layout de -variant legacy', id: 15
    Fri Feb 28 11:18:16 CET 2025 Vulcan Pro TKL updated with '-layout de -variant legacy', id: 11
    Fri Feb 28 10:34:15 CET 2025 Done

Test your keys on any place that you can write.
If you can see anything on your log or the keys are not reflecting your desired layout, check if you have the right permissions for the scripts and/or you added the correct options for your keyboard inside `usb_kb_layout.sh`.
