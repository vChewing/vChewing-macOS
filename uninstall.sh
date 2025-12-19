#!/bin/sh

# Here's how to uninstall this input method:
# 該腳本用來手動卸除該輸入法：

# Suppose that this IME is properly installed, you remove the following possible assets:
# 假設當前輸入法有正確安裝，則您需要移除下述內容：

rm -rf ~/Library/Input\ Methods/vChewing.app
rm -rf ~/Library/Keyboard\ Layouts/vChewingKeyLayout.bundle
rm ~/Library/Keyboard\ Layouts/vChewing\ MiTAC.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ IBM.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ FakeSeigyou.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ ETen.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ Dachen.keylayout
rm ~/Library/Receipts/org.atelierInmu.vChewing.bom
rm ~/Library/Receipts/org.atelierInmu.vChewing.plist

# Also user phrase folder:
# 原廠預設的使用者辭典目錄不自動刪除了，讓使用者自己刪：
# rm -rf ~/Library/Application\ Support/vChewing/
# rm -rf ~/Library/Containers/org.atelierInmu.inputmethod.vChewing/Data/Library/Application\ Support/vChewing/

# Also the IME configuration file:
# 輸入法偏好設定檔案：
rm -rf ~/Library/Preferences/org.atelierInmu.inputmethod.vChewing.plist

# If it is not properly installed, you also check the following possible paths to remove:
# 如果輸入法沒能被正確安裝的話，您還需要清理下述檔案：
sudo rm -rf /Library/Input\ Methods/vChewing.app
sudo rm -rf /Library/Keyboard\ Layouts/vChewingKeyLayout.bundle
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ MiTAC.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ IBM.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ FakeSeigyou.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ ETen.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ Dachen.keylayout
sudo rm -rf /Library/Receipts/org.atelierInmu.vChewing.bom
sudo rm -rf /Library/Receipts/org.atelierInmu.vChewing.plist

# P.S.: The "vChewingKeyLayout.bundle" and keylayout files are deployed by the pkg installer. They are not hard-requirements for running vChewing, but providing extended on-screen keyboard for MiTAC, IBM, FakeSeigyou phonetic layouts.
# P.S.: 「vChewingKeyLayout.bundle」與 keylayout 檔案只會被 pkg 格式的安裝包安裝。這些檔案提供了除了大千傳統與倚天傳統以外的靜態注音排列的螢幕鍵盤支援。

# EOF.
