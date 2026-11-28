#!/bin/bash
# 語料庫 TextMap 之產製者與 commit 指紋蓋章器。
#
# VanguardLexicon 於 `_VENDOR` 與 `_COMMIT_HASH` 兩筆 meta 條目寫入佔位符：
#   `_VENDOR_PLACEHOLDER`、`_COMMIT_HASH_PLACEHOLDER`（score 皆為 0）。
# 本倉的現代與 legacy 兩條建置鏈都在 `codesign` 之前呼叫本腳本：
#   - `_COMMIT_HASH_PLACEHOLDER` → `LexiconZone/LexiconBuildTrigger` 當前 pin 之 tag SHA
#     （取自 `Package.resolved` 的 `state.revision`；先驗其版本與 manifest 的 `exact:` 相符）；
#   - `_VENDOR_PLACEHOLDER` → 呼叫端給的 Apple Developer Team ID；建置階段尚不知簽名者，
#     故 bundle 組裝時先落 `VANGUARDLEXICON`，發佈簽名腳本再以 `--upgrade-vendor` 換成
#     實際 Team ID（取不到 Team ID 時，`VANGUARDLEXICON` 即規定的最終值）。
#
# 兩條建置鏈的落點：
#   現代：`Plugins/BundleApps/plugin.swift`（簽名前，於 `assembleMainIMEApp`）。
#   legacy：`Plugins/BundleAppsLegacy/plugin.swift`（簽名前，於 `assembleMainIMEApp`）。
# 發佈簽名：`BuildPKG.sh` 與 `Scripts/notarize-app-installers.sh`（重簽前）。
#
# 用法：
#   Scripts/stamp-lexicon-metadata.sh --path <app 或目錄> [--vendor <team-id>]
#                                    [--commit <sha>|auto|none] [--upgrade-vendor]
#                                    [--check] [--dry-run]
#
# 退出碼：0 成功；1 參數／環境錯誤、找不到 txtMap、或 `--check` 仍有佔位符。
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
PIN_SITE="$REPO_ROOT/LexiconZone/LexiconBuildTrigger"
COMMIT_PLACEHOLDER="_COMMIT_HASH_PLACEHOLDER"
VENDOR_PLACEHOLDER="_VENDOR_PLACEHOLDER"
# 需求文字曾把替換目標寫成 `_VENDORPLACEHOLDER_`；實際預設值是 `_VENDOR_PLACEHOLDER`。
# 兩者都收，以免第三方資料沿用舊寫法時靜默漏蓋。
VENDOR_PLACEHOLDER_ALIAS="_VENDORPLACEHOLDER_"
VENDOR_FALLBACK="VANGUARDLEXICON"

TARGET_PATH=""
VENDOR=""
COMMIT="auto"
UPGRADE_VENDOR=0
CHECK=0
DRY_RUN=0

usage() {
  cat <<'EOF'
用法：stamp-lexicon-metadata.sh --path <app 或目錄> [選項]

  --path <path>       要蓋章的 `.app` 或目錄（遞迴找 VanguardFactoryDict4Typing.txtMap）
  --vendor <value>    把 `_VENDOR_PLACEHOLDER` 換成此值（通常為 Apple Developer Team ID）
  --commit <value>    `auto`（預設）取 pin 的 tag SHA；`none` 不蓋 commit；或直接給 SHA
  --upgrade-vendor    一併把 `VANGUARDLEXICON` 換成 --vendor（發佈簽名前用）
  --check             只檢查是否仍有佔位符，不寫入
  --dry-run           只印出將要做的替換
  --help, -h          顯示本說明
EOF
}

die() {
  printf '錯誤：%s\n' "$*" >&2
  exit 1
}

log() {
  printf '[lexicon-metadata] %s\n' "$*"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --path)
      TARGET_PATH="${2:?--path 需要值}"
      shift 2
      ;;
    --vendor)
      VENDOR="${2:?--vendor 需要值}"
      shift 2
      ;;
    --commit)
      COMMIT="${2:?--commit 需要值}"
      shift 2
      ;;
    --upgrade-vendor)
      UPGRADE_VENDOR=1
      shift
      ;;
    --check)
      CHECK=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "不認得的選項：$1"
      ;;
  esac
done

[ -n "$TARGET_PATH" ] || die "缺少 --path。"
[ -e "$TARGET_PATH" ] || die "找不到路徑：$TARGET_PATH"

if [ -n "$VENDOR" ]; then
  case "$VENDOR" in
    *[!A-Za-z0-9._-]*) die "vendor 只接受英數與 . _ -：$VENDOR" ;;
  esac
fi

resolve_pinned_commit() {
  local manifest="$PIN_SITE/Package.swift"
  local resolved="$PIN_SITE/Package.resolved"
  [ -f "$manifest" ] || die "找不到 lexicon manifest：$manifest"
  [ -f "$resolved" ] || die "找不到 lexicon 解析結果：${resolved}（先讓 SwiftPM 解析一次）"

  local pinned resolved_version revision
  pinned=$(sed -n 's/.*exact: "\([0-9][0-9.]*\)".*/\1/p' "$manifest" | head -1)
  [ -n "$pinned" ] || die "在 $manifest 找不到 lexicon 的 exact: pin。"

  resolved_version=$(/usr/bin/plutil -extract pins.0.state.version raw -o - "$resolved" 2>/dev/null || true)
  revision=$(/usr/bin/plutil -extract pins.0.state.revision raw -o - "$resolved" 2>/dev/null || true)

  [ -n "$resolved_version" ] || die "無法自 $resolved 讀出已解析版本。"
  [ "$pinned" = "$resolved_version" ] || die \
    " lexicon pin（${pinned}）與 Package.resolved 的版本（${resolved_version}）不符；先重跑 swift package resolve。"
  if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
    die "無法自 $resolved 讀出 40 位十六進位 revision（got: ${revision:-<empty>}）。"
  fi
  printf '%s\n' "$revision"
}

COMMIT_SHA=""
case "$COMMIT" in
  none) ;;
  auto) COMMIT_SHA="$(resolve_pinned_commit)" ;;
  *)
    if [[ ! "$COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
      die "--commit 只接受 auto、none 或 40 位十六進位 SHA：$COMMIT"
    fi
    COMMIT_SHA="$COMMIT"
    ;;
esac

find_textmaps() {
  local target="$1"
  if [ -f "$target" ]; then
    printf '%s\n' "$target"
    return 0
  fi
  find "$target" -type f -name 'VanguardFactoryDict4Typing.txtMap' -print
}

declare -a TEXTMAPS=()
while IFS= read -r textmap; do
  [ -n "$textmap" ] || continue
  TEXTMAPS+=("$textmap")
done < <(find_textmaps "$TARGET_PATH")

[ "${#TEXTMAPS[@]}" -gt 0 ] || die "在 $TARGET_PATH 找不到 VanguardFactoryDict4Typing.txtMap。"

if [ "$CHECK" -eq 1 ]; then
  leftover=0
  for textmap in "${TEXTMAPS[@]}"; do
    if [ -n "$COMMIT_SHA" ] && grep -qF "$COMMIT_PLACEHOLDER" "$textmap"; then
      printf '未替換：%s 仍有 %s\n' "$textmap" "$COMMIT_PLACEHOLDER" >&2
      leftover=1
    fi
    if [ -n "$VENDOR" ] && grep -qE "$VENDOR_PLACEHOLDER|$VENDOR_PLACEHOLDER_ALIAS" "$textmap"; then
      printf '未替換：%s 仍有 vendor 佔位符\n' "$textmap" >&2
      leftover=1
    fi
  done
  [ "$leftover" -eq 0 ] || exit 1
  log "檢查通過（${#TEXTMAPS[@]} 份 txtMap）。"
  exit 0
fi

for textmap in "${TEXTMAPS[@]}"; do
  changes=()
  if [ -n "$COMMIT_SHA" ] && grep -qF "$COMMIT_PLACEHOLDER" "$textmap"; then
    changes+=("commit=$COMMIT_SHA")
  fi
  if [ -n "$VENDOR" ] && grep -qE "$VENDOR_PLACEHOLDER|$VENDOR_PLACEHOLDER_ALIAS" "$textmap"; then
    changes+=("vendor=$VENDOR")
  elif [ -n "$VENDOR" ] && [ "$UPGRADE_VENDOR" -eq 1 ] && grep -qF "$VENDOR_FALLBACK" "$textmap"; then
    changes+=("vendor=${VENDOR}（由 $VENDOR_FALLBACK 升級）")
  fi

  if [ "${#changes[@]}" -eq 0 ]; then
    log "無需變更：$textmap"
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "dry-run：$textmap → ${changes[*]}"
    continue
  fi

  if [ -n "$COMMIT_SHA" ]; then
    /usr/bin/sed -i '' "s/${COMMIT_PLACEHOLDER}/${COMMIT_SHA}/g" "$textmap"
  fi
  if [ -n "$VENDOR" ]; then
    /usr/bin/sed -i '' \
      -e "s/${VENDOR_PLACEHOLDER}/${VENDOR}/g" \
      -e "s/${VENDOR_PLACEHOLDER_ALIAS}/${VENDOR}/g" \
      "$textmap"
    if [ "$UPGRADE_VENDOR" -eq 1 ]; then
      /usr/bin/sed -i '' "s/${VENDOR_FALLBACK}/${VENDOR}/g" "$textmap"
    fi
  fi
  log "$textmap → ${changes[*]}"
done
