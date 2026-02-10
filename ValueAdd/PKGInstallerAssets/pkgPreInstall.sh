#!/bin/sh

killall vChewing || true
killall vChewingPhraseEditor || true

if [ "${login_user}" = root ]; then
    rm -rf /Library/Input\ Methods/vChewing.app || true
    rm -rf /Library/Keyboard\ Layouts/vChewingKeyLayout.bundle || true
    rm -rf /Library/Keyboard\ Layouts/vChewing\ Dachen.keylayout || true
    rm -rf /Library/Keyboard\ Layouts/vChewing\ ETen.keylayout || true
    rm -rf /Library/Keyboard\ Layouts/vChewing\ FakeSeigyou.keylayout || true
    rm -rf /Library/Keyboard\ Layouts/vChewing\ IBM.keylayout || true
    rm -rf /Library/Keyboard\ Layouts/vChewing\ MiTAC.keylayout || true
fi

rm -rf ~/Library/Input\ Methods/vChewing.app || true
rm -rf ~/Library/Keyboard\ Layouts/vChewingKeyLayout.bundle || true
rm -rf ~/Library/Keyboard\ Layouts/vChewing\ Dachen.keylayout || true
rm -rf ~/Library/Keyboard\ Layouts/vChewing\ ETen.keylayout || true
rm -rf ~/Library/Keyboard\ Layouts/vChewing\ FakeSeigyou.keylayout || true
rm -rf ~/Library/Keyboard\ Layouts/vChewing\ IBM.keylayout || true
rm -rf ~/Library/Keyboard\ Layouts/vChewing\ MiTAC.keylayout || true
