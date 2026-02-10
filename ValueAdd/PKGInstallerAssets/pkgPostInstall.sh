#!/bin/sh

TARGET='vChewing'
login_user=$(/usr/bin/stat -f%Su /dev/console)

OS_Version=$(sw_vers -productVersion)
##### if [[ ${OS_Version} < 12.0.0 ]]; then
  # Copy the wrongfully installed contents to the right location:
  cp -r /Library/Input\ Methods/"${TARGET}".app /Users/"${login_user}"/Library/Input\ Methods/ || true
  cp -r /Library/Keyboard\ Layouts/"${TARGET}"* /Users/"${login_user}"/Library/Keyboard\ Layouts/ || true

  # Clean the wrongfully installed contents:
  chown "${login_user}" /Users/"${login_user}"/Library/Input\ Methods/"${TARGET}".app || true
  chown "${login_user}" /Users/"${login_user}"/Library/Keyboard\ Layouts/"${TARGET}"* || true
  sleep 1
  rm -rf /Library/Input\ Methods/"${TARGET}".app || true
  rm -rf /Library/Keyboard\ Layouts/"${TARGET}"* || true
  sleep 1
##### fi

# Finally, register the input method:
/Users/"${login_user}"/Library/Input\ Methods/"${TARGET}".app/Contents/MacOS/"${TARGET}" install || true
