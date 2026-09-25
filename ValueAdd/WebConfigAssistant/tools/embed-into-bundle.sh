#!/bin/bash
# 唯音輸入法配置助手 // 把「教學文章」（＝配置助手之產物）收錄進輸入法之 main bundle。
#
# 用法：embed-into-bundle.sh <vChewing.app 之路徑>
#
# 收錄範圍：**只 `dist/assistant.html`**（事主 2026-09-25 明示）——單檔自足，故 `index.html`
# （目錄入口之跳轉頁）不收。落點 `<app>/Contents/Resources/assistant/assistant.html`。
#
# 三條建置路徑共用本檔，且皆於「組裝 .app 之後、**簽章之前**」呼叫（資源受簽章封印，
# 故不可於簽章後追加）：
#   * SwiftPM 現代側：`Plugins/BundleApps/plugin.swift`（`make debug`／`release`／`archive`）
#   * SwiftPM 5.10 legacy 側：`Plugins/BundleAppsLegacy/plugin.swift`
#     （`make debugLegacy`／`releaseLegacy`／`archiveLegacy`）
#   * Xcode：`vChewing.xcodeproj` 之 `vChewing` 靶上的 Run Script phase
#
# **紀律（事主 2026-09-25 明示）**：當且僅當偵測到 `tsc` 編譯器時，才編譯教學文章並收錄；
# 未偵測到即給出警告，但**絕不中斷輸入法之建置**。同理，本步之任何失敗（含 tsc 存在
# 但不可用、或助手編譯失敗）一律「警告後續行」——本步為選配。
set -u

APP="${1:-}"

warn() { echo "warning: [教學文章] $*" >&2; }

if [ -z "$APP" ]; then
  warn "用法：embed-into-bundle.sh <vChewing.app 之路徑>"
  exit 0
fi
if [ ! -d "$APP/Contents" ]; then
  warn "找不到 app bundle：$APP（略過收錄）"
  exit 0
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
ASSISTANT_DIR="$(cd "$HERE/.." && pwd)"
DEST="$APP/Contents/Resources/assistant"

# ── 唯一的閘：tsc 是否存在 ────────────────────────────────────────────────
if ! command -v tsc >/dev/null 2>&1; then
  warn "未偵測到 tsc，略過教學文章之編譯與收錄（輸入法之建置不受影響）。"
  warn "如需收錄，請安裝 TypeScript 7 之原生執行檔——見 ValueAdd/WebConfigAssistant/README.md §三。"
  exit 0
fi

echo "[教學文章] 偵測到 tsc：$(command -v tsc)"
echo "[教學文章] 編譯中…（$(basename "$ASSISTANT_DIR")）"

# `make bundle` 內含 `check-tsc`：npm 版之 tsc（`#!/usr/bin/env node` 之啟動器）會被擋下，
# 因其需 node 而本鏈已免除 node。該失敗與其他失敗一視同仁——警告後續行。
if ! make -C "$ASSISTANT_DIR" bundle; then
  warn "助手之編譯失敗，略過收錄（輸入法之建置不受影響）。"
  warn "若上方為「偵測到 tsc 是腳本」，請改用原生 tsc 7——見 ValueAdd/WebConfigAssistant/README.md §三。"
  exit 0
fi

# 只收 `assistant.html`（事主 2026-09-25 明示）——它是單檔自足之物（CSS 與 JS 皆已內聯），
# 故 `index.html`（目錄入口之跳轉頁）在本情境無用武之地，不收。
SRC="$ASSISTANT_DIR/dist/assistant.html"
if [ ! -f "$SRC" ]; then
  warn "產物缺席：$SRC（略過收錄）"
  exit 0
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp "$SRC" "$DEST/assistant.html"

echo "[教學文章] 已收錄至 $DEST/assistant.html（$(wc -c < "$DEST/assistant.html" | tr -d ' ') bytes）"
exit 0
