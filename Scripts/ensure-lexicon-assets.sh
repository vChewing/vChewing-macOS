#!/bin/sh
# 語料庫資產之「確保」入口：由三個 `.xcscheme` 的 BuildAction pre-action 呼叫，`make` 路徑不需要它
#（`make debug`／`release`／`archive`／`test` 已把 `lexiconModern` 當前置）。
#
# 為何是 pre-action 而非 build phase：帶外產製讓原廠辭典一輪建置只編一次，代價是資產成了建置前置；
# 而需要資產的是套件目標 `MainAssembly4Darwin` 本身（`LexiconAssetRelayPlugin` 於其建置規劃期執行），
# app target 的任何 Run Script phase 都排在其套件依賴建完之後，救不了冷啟。方案之 pre-action 則在整個
# 建置之前跑，是唯一夠早、又不必改動 plugin 契約的掛鉤。裸 `swift build`／`swift test` 不經 scheme，
# 仍由 relay plugin 硬報錯並指出該跑的命令。
#
# 判定「資產仍可用」（三者皆成立才跳過重建）：
#   1. 三份產物俱在 `LexiconZone/Build/`；
#   2. 同目錄之 `.lexicon-stamp` 首行（`make … collect` 寫入）與 manifest 之 `exact:` pin 相同。
# 任一不成立即跑 `make lexiconModern`（host-only、只建一次），之後再驗一次：仍不成則以非零狀態收場，
# 讓建置停在該處並留下 make 自己的訊息。
set -eu

repo_root=${1:-}
if [ -z "$repo_root" ]; then
  echo "用法：ensure-lexicon-assets.sh <倉根路徑>" >&2
  exit 2
fi

manifest="$repo_root/LexiconZone/LexiconBuildTrigger/Package.swift"
assets="$repo_root/LexiconZone/Build"
stamp="$assets/.lexicon-stamp"

# 三檔缺一不可：前兩者缺任何一份，`Bundle.currentSPM` 端會取不到片語範本。
assets_ok() {
  for name in \
    VanguardFactoryDict4Typing.txtMap \
    template-associatedPhrases-cht.txt \
    template-associatedPhrases-chs.txt; do
    [ -f "$assets/$name" ] || return 1
  done
  return 0
}

stamp_matches() {
  [ -f "$stamp" ] || return 1
  [ "$(head -1 "$stamp")" = "$pinned" ]
}

pinned=$(sed -n 's/.*exact: "\([0-9][0-9.]*\)".*/\1/p' "$manifest" | head -1)
if [ -z "$pinned" ]; then
  echo "錯誤：在 $manifest 找不到 lexicon 版本 pin。" >&2
  exit 1
fi

if assets_ok && stamp_matches; then
  exit 0
fi

echo "note: 語料庫資產與 lexicon pin（$pinned）不符或不存在，先跑 make lexiconModern…" >&2
# `MODERN_SWIFT_EXTRA_FLAGS` 由呼叫端（plugin 會把建置環境原樣帶入）轉遞，供受拘束之 shell 傳
# `--disable-sandbox` 一類旗標；正常環境不設，manifest 沙箱照舊。
if [ -n "${MODERN_SWIFT_EXTRA_FLAGS:-}" ]; then
  /usr/bin/make -C "$repo_root" lexiconModern MODERN_SWIFT_EXTRA_FLAGS="$MODERN_SWIFT_EXTRA_FLAGS"
else
  /usr/bin/make -C "$repo_root" lexiconModern
fi

if ! assets_ok || ! stamp_matches; then
  echo "錯誤：make lexiconModern 之後，$assets 仍不完整或仍與 pin（$pinned）不符。" >&2
  exit 1
fi
