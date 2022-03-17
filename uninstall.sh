#!/bin/sh

# Here's how to uninstall this input method:

# Suppose that this IME is properly installed, you remove the following possible assets:

rm -rf ~/Library/Input\ Methods/vChewing.app
rm -rf ~/Library/Keyboard\ Layouts/vChewingKeyLayout.bundle
rm ~/Library/Keyboard\ Layouts/vChewing\ MiTAC.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ IBM.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ FakeSeigyou.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ ETen.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ Dachen.keylayout

# Also user phrase folder:
rm -rf ~/Library/Application\ Support/vChewing/

# Also the IME configuration file:
rm -rf ~/Library/Preferences/org.atelierInmu.inputmethod.vChewing.plist

# If you have ever tried the initial alpha builds of vChewing, you also remove:
rm -rf ~/Library/Preferences/org.openvanilla.inputmethod.vChewing.plist

# If it is not properly installed, you also check the following possible paths to remove:
sudo rm -rf /Library/Input\ Methods/vChewing.app
sudo rm -rf /Library/Keyboard\ Layouts/vChewingKeyLayout.bundle
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ MiTAC.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ IBM.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ FakeSeigyou.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ ETen.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ Dachen.keylayout

# P.S.: The "vChewingKeyLayout.bundle" and keylayout files are deployed by the pkg installer. They are not hard-requirements for running vChewing, but providing extended on-screen keyboard for MiTAC, IBM, FakeSeigyou phonetic layouts.

# EOF.

