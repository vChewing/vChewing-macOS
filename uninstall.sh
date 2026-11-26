#!/bin/sh

# Here's how to uninstall this input method:
# 該腳本用來手動卸除該輸入法：

# Suppose that this IME is properly installed, you remove the following possible assets:
# 假設當前輸入法有正確安裝，則您需要移除下述內容：

rm -rf ~/Library/Input\ Methods/vChewing.app
# 佈局 bundle 僅存在於 v5.0.6 及更早之安裝；自 v5.0.7 起不再隨安裝包提供，列出僅為清理殘檔。
rm -rf ~/Library/Keyboard\ Layouts/vChewingKeyLayout.bundle
rm ~/Library/Keyboard\ Layouts/vChewing\ MiTAC.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ IBM.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ FakeSeigyou.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ Seigyou.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ ETen.keylayout
rm ~/Library/Keyboard\ Layouts/vChewing\ Dachen.keylayout
rm ~/Library/Receipts/org.atelierInmu.vChewing.bom
rm ~/Library/Receipts/org.atelierInmu.vChewing.plist

# Also user phrase folder:
# 原廠預設的使用者片語辭典目錄不自動刪除了，讓使用者自己刪：
# rm -rf ~/Library/Application\ Support/vChewing/
# rm -rf ~/Library/Containers/org.atelierInmu.inputmethod.vChewing/Data/Library/Application\ Support/vChewing/

# Also the IME configuration file:
# 輸入法偏好設定檔案：
rm -rf ~/Library/Preferences/org.atelierInmu.inputmethod.vChewing.plist

# If it is not properly installed, you also check the following possible paths to remove:
# 如果輸入法沒能被正確安裝的話，您還需要清理下述檔案：
sudo rm -rf /Library/Input\ Methods/vChewing.app
# 同上（系統層殘檔）。
sudo rm -rf /Library/Keyboard\ Layouts/vChewingKeyLayout.bundle
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ MiTAC.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ IBM.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ FakeSeigyou.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ Seigyou.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ ETen.keylayout
sudo rm -rf /Library/Keyboard\ Layouts/vChewing\ Dachen.keylayout
sudo rm -rf /Library/Receipts/org.atelierInmu.vChewing.bom
sudo rm -rf /Library/Receipts/org.atelierInmu.vChewing.plist

# P.S. The six `vChewing *.keylayout` files are still installed by the pkg installer (they keep the
# on-screen keyboard working during the first login cycle, before the input method's own private
# copies become visible to other processes). `vChewingKeyLayout.bundle` is a legacy artifact of
# releases up to 5.0.6 and is listed above only for cleanup.
# P.S. 六份 `vChewing *.keylayout` 仍由 pkg 安裝包安裝：輸入法自帶的私有佈局須跨一次登入週期才對
# 其他行程可見，故首個登入週期仍靠這些鬆散檔提供螢幕鍵盤。`vChewingKeyLayout.bundle` 係 5.0.6 以前
# 之產物，列於此僅為清理殘檔。

# EOF.
