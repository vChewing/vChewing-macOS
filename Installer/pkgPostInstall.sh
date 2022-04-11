#!/bin/sh

TARGET='vChewing'
login_user=$(/usr/bin/stat -f%Su /dev/console)

# First, copy the wrongfully installed contents to the right location:
cp -r /Library/Input\ Methods/"${TARGET}".app /Users/"${login_user}"/Library/Input\ Methods/ || true
cp -r /Library/Keyboard\ Layouts/"${TARGET}"* /Users/"${login_user}"/Library/Keyboard\ Layouts/ || true
chown "${login_user}" /Users/"${login_user}"/Library/Input\ Methods/"${TARGET}".app || true
chown "${login_user}" /Users/"${login_user}"/Library/Keyboard\ Layouts/"${TARGET}"* || true

sleep 1

# Second, clean the wrongfully installed contents:
rm -rf /Library/Input\ Methods/"${TARGET}".app || true
rm -rf /Library/Keyboard\ Layouts/"${TARGET}"* || true
sleep 1

# Finally, register the input method:
/Users/"${login_user}"/Library/Input\ Methods/"${TARGET}".app/Contents/MacOS/"${TARGET}" install --all || true
