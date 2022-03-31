#!/bin/sh
loggedInUser=$(stat -f%Su /dev/console)

killall vChewing || true

if [ "$loggedInUser" = root ]; then
    rm -rf /Library/Input\ Methods/vChewing.app || true
    rm -rf /Library/Keyboard\ Layouts/vChewingKeyLayout.bundle || true
    rm -rf /Library/Keyboard\ Layouts/vChewing\ Dachen.keylayout || true
    rm -rf /Library/Keyboard\ Layouts/vChewing\ ETen.keylayout || true
    rm -rf /Library/Keyboard\ Layouts/vChewing\ FakeSeigyou.keylayout || true
    rm -rf /Library/Keyboard\ Layouts/vChewing\ IBM.keylayout || true
    rm -rf /Library/Keyboard\ Layouts/vChewing\ MiTAC.keylayout || true
fi

rm -rf ~/Library/Input\ Methods/vChewing.app
rm -rf ~/Library/Keyboard\ Layouts/vChewingKeyLayout.bundle
rm -rf ~/Library/Keyboard\ Layouts/vChewing\ Dachen.keylayout
rm -rf ~/Library/Keyboard\ Layouts/vChewing\ ETen.keylayout
rm -rf ~/Library/Keyboard\ Layouts/vChewing\ FakeSeigyou.keylayout
rm -rf ~/Library/Keyboard\ Layouts/vChewing\ IBM.keylayout
rm -rf ~/Library/Keyboard\ Layouts/vChewing\ MiTAC.keylayout
