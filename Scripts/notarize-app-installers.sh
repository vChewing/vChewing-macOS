#!/bin/bash
# 兩顆 `.app` 版安裝包的公證產線：把 `make archive`／`make archiveLegacy` 留在
# `~/Library/Developer/Xcode/Archives/<date>/` 的 `.xcarchive`，變成
# 「已用 Developer ID 重簽、已公證、已 staple」的 `.app` 與其 `ditto` zip。
#
# 從前這一步只能在 Xcode Organizer 裡手動 Distribute：Organizer 乾的活其實就是
# ① 由內而外重簽、② `notarytool` 送審、③ 把回條 staple 回 bundle。三者都有 CLI，
# 故本腳本照抄那條路，只是把「哪個 bundle 用哪份 entitlements」交給 archive 自己交代——
# archive 裡的 bundle 雖是 adhoc 簽章，但各 bundle 的 entitlements 早已由 `BundleApps`／
# `BundleAppsLegacy` 蓋好（外層安裝器帶 `disable-library-validation`，內嵌的 IME 帶
# 沙盒與那串 temporary-exception），於是逐件 `codesign -d --entitlements :-` 取回再套，
# 既不猜也不漏。`BuildPKG.sh --sign` 走的是同一條路，差別只在它簽的是 pkg 內的暫存副本。
#
# 為何非得由內而外：bundle 的 CodeDirectory 會記住主執行檔的雜湊，先簽 bundle 再動
# 裡面的執行檔等於把簽章弄壞。故簽章次序按「路徑深度」由深到淺排，外層安裝器永遠最後。
#
# 送審用 zip 而非 .app：`notarytool` 只收 zip／pkg／dmg；回條則必須 staple 回未壓縮的
# `.app`（zip 內塞不進去），故流程是「zip 送審 → staple .app → 再 zip 一次」，對外發佈的
# 那一份因此必然帶回條。離線執行時 `spctl` 也能放行，這正是本腳本存在的理由。
#
# 憑證：`notarytool` 的 keychain profile（預設 `AC_PASSWORD`，與 `BuildPKG.sh` 同一個）。
# 用法：
#   ./Scripts/notarize-app-installers.sh                  # 兩顆都做，產物落 Build/Notarized/
#   ./Scripts/notarize-app-installers.sh --only modern     # 只做現代版
#   ./Scripts/notarize-app-installers.sh --sign-only       # 只重簽＋驗章，不送審（不產出可發佈物）
# 選項見 `--help`。
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

ARCHIVE_ROOT="${ARCHIVE_ROOT:-$HOME/Library/Developer/Xcode/Archives}"
IDENTITY="${VCHEWING_TEAM_ID:-WEY3MS268C}"
PROFILE="AC_PASSWORD"
OUT_DIR="Build/Notarized"
STAGING_ROOT="Build/Notarization"
ONLY=""
SIGN_ONLY=0
KEEP_STAGING=0
MODERN_ARCHIVE=""
LEGACY_ARCHIVE=""

usage() {
  cat <<'EOF'
用法：notarize-app-installers.sh [選項]

  --modern <path.xcarchive>   指定現代版安裝器的 archive（預設取最新一份）
  --legacy <path.xcarchive>   指定 legacy（Aqua）版安裝器的 archive（預設取最新一份）
  --only modern|legacy        只處理其中一顆
  --out <dir>                 zip 產物目錄（預設 Build/Notarized）
  --identity <id|team-id>     codesign 身分（預設 $VCHEWING_TEAM_ID，否則 WEY3MS268C）
  --profile <name>            notarytool 的 keychain profile（預設 AC_PASSWORD）
  --sign-only                 只重簽與驗章，不送審、不 staple（產物不可發佈）
  --keep-staging              保留 Build/Notarization/ 內的暫存 bundle
  --help, -h                  顯示本說明

產物：
  vChewing-macOS-<版本>-signed-alternative.zip   現代版（vChewingInstaller.app）
  vChewingAqua-<版本>-signed.zip                  legacy 版（vChewingInstallerLegacy.app）
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --modern) MODERN_ARCHIVE="${2:?--modern 需要路徑}"; shift 2 ;;
    --legacy) LEGACY_ARCHIVE="${2:?--legacy 需要路徑}"; shift 2 ;;
    --only) ONLY="${2:?--only 需要 modern 或 legacy}"; shift 2 ;;
    --out) OUT_DIR="${2:?--out 需要目錄}"; shift 2 ;;
    --identity) IDENTITY="${2:?--identity 需要值}"; shift 2 ;;
    --profile) PROFILE="${2:?--profile 需要值}"; shift 2 ;;
    --sign-only) SIGN_ONLY=1; shift ;;
    --keep-staging) KEEP_STAGING=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "錯誤：不認得的選項 $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$ONLY" in
  ""|modern|legacy) ;;
  *) echo "錯誤：--only 只收 modern 或 legacy。" >&2; exit 2 ;;
esac

MARKETING_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Release-Version.plist)

log() { printf '%s\n' "$*"; }
die() { printf '錯誤：%s\n' "$*" >&2; exit 1; }

# 最新一份 archive：檔名形如 `vChewingInstaller-2026-11-13-0212hrs.xcarchive`、
# `vChewingInstallerLegacy-2026-11-13-0212hrs.xcarchive`。兩者的前綴互不包含，故用
# `vChewingInstaller-` 不會誤中 legacy 那一份。
newest_archive() {
  local stem="$1"
  ls -dt "$ARCHIVE_ROOT"/*/"${stem}"-*.xcarchive 2>/dev/null | head -n 1 || true
}

archive_version() {
  /usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' \
    "$1/Info.plist" 2>/dev/null || true
}

# 逐件重簽：先取回既有的 entitlements，再有則套、無則不套。
re_sign() {
  local target="$1"
  local ent
  ent="$(mktemp -t vchewing-entitlements)"
  if codesign -d --entitlements :- "$target" >"$ent" 2>/dev/null && [ -s "$ent" ]; then
    codesign --force --options runtime --timestamp --sign "$IDENTITY" \
      --entitlements "$ent" "$target"
  else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$target"
  fi
  rm -f "$ent"
}

# 列出該簽的每一件：巢狀 bundle（.app／.framework／.xpc／.appex，以及帶 Info.plist 的
# .bundle）與每一個 Mach-O，各自附上路徑深度，供由深到淺排序。
collect_targets() {
  local app="$1"
  {
    find "$app" -mindepth 1 -type d \
      \( -name '*.app' -o -name '*.framework' -o -name '*.xpc' -o -name '*.appex' \) -print
    # 資源型 bundle 沒有主執行檔，簽它只會多出無用的 _CodeSignature；只有帶 Info.plist 的才收。
    while IFS= read -r bundle; do
      [ -f "$bundle/Contents/Info.plist" ] && printf '%s\n' "$bundle"
    done < <(find "$app" -mindepth 1 -type d -name '*.bundle' -print)
    # Mach-O：`file` 對多架構二進位會斷成多行、欄位又用空白補齊，故先按可執行位篩候選，
    # 再逐件 `file -b` 確認（兩顆 bundle 內不過數十件，成本可忽略）。
    while IFS= read -r candidate; do
      case "$(file -b "$candidate" 2>/dev/null)" in
        Mach-O*) printf '%s\n' "$candidate" ;;
      esac
    done < <(find "$app" -type f -perm -u+x -print)
  } | awk '{ n=gsub(/\//, "/"); print n "\t" $0 }' | sort -t "$(printf '\t')" -k1,1nr \
    | cut -f2-
}

verify_signature() {
  local app="$1"
  local target info failures=0 total=0
  log "  ── 驗章 ──"
  codesign --verify --deep --strict --verbose=2 "$app" 2>&1 | tail -2
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    total=$((total + 1))
    # 不寫成 `codesign … | grep -q`：`set -o pipefail` 之下 `grep -q` 尋得即收工，
    # 左側的 codesign 收到 SIGPIPE，管線狀態會變成失敗，於是每一件都被誤報成沒簽。
    info="$(codesign -dvvv "$target" 2>&1 || true)"
    case "$info" in
      *"Authority=Developer ID Application"*) ;;
      *)
        log "  ✗ 未以 Developer ID 簽章：${target#"$PWD"/}"
        failures=$((failures + 1))
        ;;
    esac
  done < <(collect_targets "$app")
  if [ "$failures" -ne 0 ]; then
    die "有 $failures 件程式碼未以 Developer ID Application 簽章（共 $total 件）。"
  fi
  log "  ✓ $total 件程式碼皆為 Developer ID Application 簽章"
  codesign -dvvv "$app" 2>&1 \
    | grep -E "Authority=Developer|TeamIdentifier|Timestamp|Runtime Version" | sed 's/^/    /'
}

notarize_bundle() {
  local app="$1" zip="$2"
  local result submission_id status
  result="$(mktemp -t vchewing-notary)"
  log "  ── 送審 ──"
  log "  壓縮：$(basename "$zip")"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
  log "  送交 Apple（profile：$PROFILE）…這一步通常要幾分鐘。"
  xcrun notarytool submit "$zip" --keychain-profile "$PROFILE" --wait \
    --output-format json >"$result" 2>/dev/null || true
  submission_id="$(plutil -extract id raw -o - "$result" 2>/dev/null || true)"
  status="$(plutil -extract status raw -o - "$result" 2>/dev/null || true)"
  if [ "$status" != "Accepted" ]; then
    printf '錯誤：公證未通過（status=%s，id=%s）。\n' "${status:-未知}" "${submission_id:-未知}" >&2
    if [ -n "$submission_id" ]; then
      xcrun notarytool log "$submission_id" --keychain-profile "$PROFILE" >&2 || true
    fi
    rm -f "$result"
    exit 1
  fi
  rm -f "$result"
  log "  ✓ 公證通過（id：$submission_id）"

  log "  ── staple ──"
  xcrun stapler staple "$app"
  xcrun stapler validate "$app" >/dev/null
  local gatekeeper
  gatekeeper="$(spctl -a -vv "$app" 2>&1 || true)"
  case "$gatekeeper" in
    *accepted*) ;;
    *)
      printf '%s\n' "$gatekeeper" >&2
      die "staple 後仍無法通過 Gatekeeper 評定。"
      ;;
  esac
  log "  ✓ 回條已內嵌，Gatekeeper 評定為 Notarized Developer ID"

  # 回條是 staple 進 .app 的，故發佈用的 zip 必須在 staple 之後重壓一份。
  log "  ── 重新壓縮（帶回條）──"
  rm -f "$zip"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
}

process_artifact() {
  local label="$1" archive="$2" app_name="$3" zip_name="$4"
  local apps_dir="$archive/Products/Applications"
  local staged="$STAGING_ROOT/$app_name"
  local zip="$OUT_DIR/$zip_name"
  local version

  log ""
  log "== $label =="
  [ -d "$archive" ] || die "找不到 archive：$archive"
  log "  archive：${archive#"$HOME"/}"

  version="$(archive_version "$archive")"
  if [ "$version" != "$MARKETING_VERSION" ]; then
    die "archive 版本（${version:-未知}）與 Release-Version.plist（$MARKETING_VERSION）不符；請先重跑該 archive 目標。"
  fi
  log "  版本：$version"

  [ -d "$apps_dir/$app_name" ] || die "archive 內沒有 $app_name：$apps_dir"
  rm -rf "$staged"
  mkdir -p "$STAGING_ROOT"
  ditto "$apps_dir/$app_name" "$staged"

  log "  ── 由內而外重簽 ──"
  local target count=0
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    re_sign "$target"
    count=$((count + 1))
  done < <(collect_targets "$staged")
  re_sign "$staged"
  log "  ✓ 已重簽 $((count + 1)) 件（含外層安裝器）"

  verify_signature "$staged"

  mkdir -p "$OUT_DIR"
  if [ "$SIGN_ONLY" -eq 1 ]; then
    log "  ⚠️  --sign-only：未送審、未 staple，故本腳本不產出 zip。"
    return 0
  fi

  notarize_bundle "$staged" "$zip"

  log "  ── 完成 ──"
  printf '  %s  %s\n' "$(shasum -a 256 "$zip" | awk '{print $1}')" "$(basename "$zip")"
  du -h "$zip" | awk '{print "  大小：" $1}'
}

# ── 前置檢查 ─────────────────────────────────────────────────────────

[ -f Release-Version.plist ] || die "這裡不像 vChewing-macOS 倉根（找不到 Release-Version.plist）。"
command -v xcrun >/dev/null || die "找不到 xcrun。"
identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
case "$identities" in
  *"Developer ID Application"*) ;;
  *) die "keychain 內沒有 Developer ID Application 憑證。" ;;
esac
[ "$SIGN_ONLY" -eq 1 ] || xcrun notarytool --version >/dev/null 2>&1 || die "notarytool 不可用。"

log "vChewing .app 版安裝包公證產線（版本 $MARKETING_VERSION）"
if [ "$SIGN_ONLY" -eq 1 ]; then
  log "⚠️  --sign-only：僅重簽與驗章。"
fi

# ── 兩顆安裝器 ───────────────────────────────────────────────────────

if [ "$ONLY" != "legacy" ]; then
  [ -n "$MODERN_ARCHIVE" ] || MODERN_ARCHIVE="$(newest_archive vChewingInstaller)"
  [ -n "$MODERN_ARCHIVE" ] || die "在 $ARCHIVE_ROOT 找不到現代版的 archive；請先跑 make archive。"
  process_artifact "現代版安裝器" "$MODERN_ARCHIVE" "vChewingInstaller.app" \
    "vChewing-macOS-$MARKETING_VERSION-signed-alternative.zip"
fi

if [ "$ONLY" != "modern" ]; then
  [ -n "$LEGACY_ARCHIVE" ] || LEGACY_ARCHIVE="$(newest_archive vChewingInstallerLegacy)"
  [ -n "$LEGACY_ARCHIVE" ] || die "在 $ARCHIVE_ROOT 找不到 legacy 版的 archive；請先跑 make archiveLegacy。"
  process_artifact "legacy（Aqua）版安裝器" "$LEGACY_ARCHIVE" "vChewingInstallerLegacy.app" \
    "vChewingAqua-$MARKETING_VERSION-signed.zip"
fi

if [ "$KEEP_STAGING" -eq 0 ] && [ "$SIGN_ONLY" -eq 0 ]; then
  rm -rf "$STAGING_ROOT"
fi

log ""
log "產物目錄：$OUT_DIR"
