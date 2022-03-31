#!/bin/sh
loggedInUser=$(stat -f%Su /dev/console)

# First, copy the wrongfully installed contents to the right location:
cp -r /Library/Input\ Methods/vChewing.app /Users/$(stat -f%Su /dev/console)/Library/Input\ Methods/ || true
cp -r /Library/Keyboard\ Layouts/vChewing* /Users/$(stat -f%Su /dev/console)/Library/Keyboard\ Layouts/ || true
chown "$loggedInUser" /Users/$(stat -f%Su /dev/console)/Library/Input\ Methods/vChewing.app || true
chown "$loggedInUser" /Users/$(stat -f%Su /dev/console)/Library/Keyboard\ Layouts/vChewing* || true

sleep 1

# Second, clean the wrongfully installed contents:
rm -rf /Library/Input\ Methods/vChewing.app || true
rm -rf /Library/Keyboard\ Layouts/vChewing* || true
sleep 1

# Finally, register the input method:
/Users/$(stat -f%Su /dev/console)/Library/Input\ Methods/vChewing.app/Contents/MacOS/vChewing install --all || true
