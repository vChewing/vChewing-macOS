#!/bin/sh

# Here's how to fix this input method, removing unnecessary files outside of the user directory:

sudo rm -rf /Library/Input\ Methods/vChewing.app
# 佈局 bundle 僅存在於 v5.0.6 及更早之安裝；自 v5.0.7 起不再隨安裝包提供，列出僅為清理殘檔。
sudo rm -rf /Library/Keyboard\ Layouts/vChewingKeyLayout.bundle
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ MiTAC.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ IBM.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ FakeSeigyou.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ Seigyou.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ ETen.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ Dachen.keylayout
sudo rm -rf /Library/Receipts/org.atelierInmu.vChewing.bom
sudo rm -rf /Library/Receipts/org.atelierInmu.vChewing.plist
