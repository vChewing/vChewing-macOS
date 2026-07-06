#!/bin/sh
# BuildPKG.sh
# Builds the vChewing PKG installer using pkgbuild + productbuild.
# The resulting installer always targets the current user's home directory and
# never requests administrator credentials unless a suspicious vChewing bundle
# is detected in /Library/Input Methods that needs to be renamed.

set -e

# Run a command while filtering out harmless cosmetic messages emitted by
# pkgbuild/productbuild on recent macOS versions (e.g. "write: Permission denied"
# when the tool tries to preserve extended attributes). Real errors are still
# forwarded to stderr and the original exit status is preserved.
run_with_filtered_stderr() {
    local stderr_file
    stderr_file=$(mktemp /tmp/vchewing-pkgbuild-stderr.XXXXXX)
    "$@" 2>"${stderr_file}"
    local status=$?
    grep -v '^write: Permission denied$' "${stderr_file}" >&2 || true
    rm -f "${stderr_file}"
    return ${status}
}

# Determine the project root (where this script lives).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

# Read the canonical version from Release-Version.plist.
if [ ! -f "Release-Version.plist" ]; then
    echo "Error: Release-Version.plist not found in project root." >&2
    exit 1
fi

MARKETING_VERSION=$(plutil -extract CFBundleShortVersionString raw "Release-Version.plist" 2>/dev/null || echo "")
BUILD_VERSION=$(plutil -extract CFBundleVersion raw "Release-Version.plist" 2>/dev/null || echo "")

if [ -z "${MARKETING_VERSION}" ] || [ -z "${BUILD_VERSION}" ]; then
    echo "Error: Could not read version from Release-Version.plist." >&2
    exit 1
fi

TARGET='vChewing'
IME_APP="Build/Products/Release/${TARGET}.app"
KEYLAYOUT_BUNDLE="Sources/vChewingIME_macOS/Resources/vChewingKeyLayout.bundle"
KEYLAYOUT_RESOURCES="${KEYLAYOUT_BUNDLE}/Contents/Resources"
ASSETS_DIR="ValueAdd/PKGInstallerAssets"
OUTPUT_DIR="Build"

# Allow command-line overrides: BuildPKG.sh [--sign [TEAM_ID]]
# Version information is always read from Release-Version.plist.
SIGN_PRODUCT=0
# Default Team ID for vChewing release builds. Override with --sign <TEAM_ID>
# or by setting the VCHEWING_TEAM_ID environment variable.
DEFAULT_TEAM_ID="WEY3MS268C"
TEAM_ID="${VCHEWING_TEAM_ID:-${DEFAULT_TEAM_ID}}"

while [ $# -gt 0 ]; do
    case "$1" in
        --sign)
            SIGN_PRODUCT=1
            if [ -n "$2" ] && [ "${2#--}" = "$2" ]; then
                TEAM_ID="$2"
                shift
            fi
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 [--sign [TEAM_ID]]

Options:
  --sign [TEAM_ID]  Sign the app bundle and product archive, submit the
                    package for notarization, and staple the ticket.
                    TEAM_ID defaults to WEY3MS268C (or the
                    VCHEWING_TEAM_ID environment variable if set).
  --help, -h        Show this help message.

Notarization uses the notarytool keychain profile named AC_PASSWORD.
EOF
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
    shift
done

if [ "${SIGN_PRODUCT}" -eq 1 ] && [ -z "${TEAM_ID}" ]; then
    echo "Error: --sign requires a Team ID." >&2
    echo "Provide it as an argument or set the VCHEWING_TEAM_ID environment variable." >&2
    exit 1
fi

if [ "${SIGN_PRODUCT}" -eq 1 ]; then
    PKG_NAME="${TARGET}-macOS-${MARKETING_VERSION}-signed.pkg"
else
    PKG_NAME="${TARGET}-macOS-${MARKETING_VERSION}-unsigned.pkg"
fi

if [ ! -d "${IME_APP}" ]; then
    echo "Error: ${IME_APP} not found." >&2
    echo "Build the app bundle first, for example:" >&2
    echo "  make release" >&2
    exit 1
fi

if [ ! -d "${KEYLAYOUT_BUNDLE}" ]; then
    echo "Error: ${KEYLAYOUT_BUNDLE} not found." >&2
    exit 1
fi

# Prepare a local staging area.
STAGING_ROOT="${SCRIPT_DIR}/.build/pkg-staging/root"
RESOURCES_STAGING="${SCRIPT_DIR}/.build/pkg-staging/resources"
SCRIPTS_STAGING="${SCRIPT_DIR}/.build/pkg-staging/scripts"
DISTRIBUTION_XML="${SCRIPT_DIR}/.build/pkg-staging/distribution.xml"
ENTITLEMENTS_STAGING="${SCRIPT_DIR}/.build/pkg-staging/vChewing.entitlements"
rm -rf "${SCRIPT_DIR}/.build/pkg-staging"
mkdir -p "${STAGING_ROOT}/Library/Input Methods"
mkdir -p "${STAGING_ROOT}/Library/Keyboard Layouts"
mkdir -p "${RESOURCES_STAGING}"
mkdir -p "${SCRIPTS_STAGING}"

cleanup_staging() {
    rm -rf "${SCRIPT_DIR}/.build/pkg-staging"
}
trap cleanup_staging EXIT

# Stage the IME app bundle.
cp -R "${IME_APP}" "${STAGING_ROOT}/Library/Input Methods/"

# Stage the keyboard layout bundle.
cp -R "${KEYLAYOUT_BUNDLE}" "${STAGING_ROOT}/Library/Keyboard Layouts/"

# Stage individual .keylayout files.
for keylayout in "${KEYLAYOUT_RESOURCES}"/vChewing*.keylayout; do
    [ -e "${keylayout}" ] || continue
    cp "${keylayout}" "${STAGING_ROOT}/Library/Keyboard Layouts/"
done

# Inspect the signature on a bundle. Returns 0 if the bundle is signed by the
# given Team ID and spctl accepts it, 1 otherwise.
bundle_is_signed_by_team() {
    bundle_path="$1"
    team_id="$2"
    [ -d "${bundle_path}" ] || return 1
    bundle_id=$(codesign -dv "${bundle_path}" 2>&1 | awk -F= '/TeamIdentifier/{print $2}')
    if [ "${bundle_id}" != "${team_id}" ]; then
        return 1
    fi
    spctl -a -vv "${bundle_path}" >/dev/null 2>&1
}

# When requested, sign the staged app bundle and keyboard layout bundle with the
# Developer ID Application identity associated with the given Team ID. The
# entitlements file used by the Xcode/SPM build is copied into staging with
# bundle-identifier placeholders resolved so codesign can apply it.
# Bundles already signed by the same Team ID and accepted by spctl are left
# untouched, because re-signing would invalidate an existing notarization ticket.
if [ "${SIGN_PRODUCT}" -eq 1 ]; then
    ENTITLEMENTS_SRC="Sources/vChewingIME_macOS/Resources/vChewing.entitlements"
    if bundle_is_signed_by_team "${STAGING_ROOT}/Library/Input Methods/${TARGET}.app" "${TEAM_ID}"; then
        echo "App bundle is already signed by Team ID ${TEAM_ID}; skipping re-sign."
    else
        echo "Signing app bundle with Team ID ${TEAM_ID}..."
        if [ -f "${ENTITLEMENTS_SRC}" ]; then
            sed -e 's/\$(PRODUCT_BUNDLE_IDENTIFIER)/org.atelierInmu.inputmethod.vChewing/g' \
                "${ENTITLEMENTS_SRC}" > "${ENTITLEMENTS_STAGING}"
            codesign --force --deep --sign "${TEAM_ID}" \
                --entitlements "${ENTITLEMENTS_STAGING}" \
                --options runtime \
                --timestamp \
                "${STAGING_ROOT}/Library/Input Methods/${TARGET}.app"
        else
            codesign --force --deep --sign "${TEAM_ID}" \
                --options runtime \
                --timestamp \
                "${STAGING_ROOT}/Library/Input Methods/${TARGET}.app"
        fi
        codesign --verify --verbose=1 \
            "${STAGING_ROOT}/Library/Input Methods/${TARGET}.app" || true
    fi

    if [ -d "${STAGING_ROOT}/Library/Keyboard Layouts/vChewingKeyLayout.bundle" ]; then
        if bundle_is_signed_by_team "${STAGING_ROOT}/Library/Keyboard Layouts/vChewingKeyLayout.bundle" "${TEAM_ID}"; then
            echo "Keyboard layout bundle is already signed by Team ID ${TEAM_ID}; skipping re-sign."
        else
            echo "Signing keyboard layout bundle with Team ID ${TEAM_ID}..."
            codesign --force --sign "${TEAM_ID}" \
                --options runtime \
                --timestamp \
                "${STAGING_ROOT}/Library/Keyboard Layouts/vChewingKeyLayout.bundle"
        fi
    fi
fi

# Stage installer scripts with the canonical names expected by pkgbuild.
cp "${ASSETS_DIR}/pkgPreInstall.sh" "${SCRIPTS_STAGING}/preinstall"
cp "${ASSETS_DIR}/pkgPostInstall.sh" "${SCRIPTS_STAGING}/postinstall"
chmod +x "${SCRIPTS_STAGING}/preinstall" "${SCRIPTS_STAGING}/postinstall"

# Installer.app derives the product title from the text of the single <title>
# element by looking it up in Resources/<locale>.lproj/Localizable.strings.
# Using one non-localized title key plus per-locale Localizable.strings avoids
# the broken xml:lang matching in modern macOS Installer (which otherwise picks
# the last <title> tag regardless of the user's language).
INSTALLER_TITLE_KEY="vChewing Input Method"

localize_title() {
    lproj="$1"
    value="$2"
    mkdir -p "${RESOURCES_STAGING}/${lproj}"
    printf '"%s" = "%s";\n' "${INSTALLER_TITLE_KEY}" "${value}" \
        > "${RESOURCES_STAGING}/${lproj}/Localizable.strings"
}

localize_title "en.lproj" "vChewing Input Method"
localize_title "ja.lproj" "唯音入力アプリ"
localize_title "zh-Hans.lproj" "唯音输入法"
localize_title "zh-Hans-CN.lproj" "唯音输入法"
localize_title "zh-Hant.lproj" "唯音輸入法"
localize_title "zh-Hant-TW.lproj" "唯音輸入法"

# Localize presentation resources into standard lproj directories.
localize_resource() {
    src_path="${ASSETS_DIR}/$1"
    lproj="$2"
    dst_name="$3"
    if [ -f "${src_path}" ]; then
        mkdir -p "${RESOURCES_STAGING}/${lproj}"
        cp "${src_path}" "${RESOURCES_STAGING}/${lproj}/${dst_name}"
    fi
}

localize_resource "pkgTextWarning-ENU.txt" "en.lproj" "welcome.txt"
localize_resource "pkgTextWarning-CHT.txt" "zh-Hant.lproj" "welcome.txt"
localize_resource "pkgTextWarning-CHS.txt" "zh-Hans.lproj" "welcome.txt"
localize_resource "pkgTextWarning-JPN.txt" "ja.lproj" "welcome.txt"

localize_resource "pkgTextSuccessful-ENU.rtf" "en.lproj" "conclusion.rtf"
localize_resource "pkgTextSuccessful-CHT.rtf" "zh-Hant.lproj" "conclusion.rtf"
localize_resource "pkgTextSuccessful-CHS.rtf" "zh-Hans.lproj" "conclusion.rtf"
localize_resource "pkgTextSuccessful-JPN.rtf" "ja.lproj" "conclusion.rtf"

localize_resource "LICENSE.txt" "en.lproj" "license.txt"
localize_resource "LICENSE-CHT.txt" "zh-Hant.lproj" "license.txt"
localize_resource "LICENSE-CHS.txt" "zh-Hans.lproj" "license.txt"
localize_resource "LICENSE-JPN.txt" "ja.lproj" "license.txt"

# Unlocalized background images.
if [ -f "${ASSETS_DIR}/InstallerBg.png" ]; then
    cp "${ASSETS_DIR}/InstallerBg.png" "${RESOURCES_STAGING}/InstallerBg.png"
fi
if [ -f "${ASSETS_DIR}/InstallerBg@2x.png" ]; then
    cp "${ASSETS_DIR}/InstallerBg@2x.png" "${RESOURCES_STAGING}/InstallerBg@2x.png"
fi

# Build the component package. The install-location is the root of the chosen
# target volume; combined with -target CurrentUserHomeDirectory this installs
# directly into ~/Library/Input Methods and ~/Library/Keyboard Layouts.
mkdir -p "${OUTPUT_DIR}"
run_with_filtered_stderr pkgbuild \
    --root "${STAGING_ROOT}" \
    --install-location "/" \
    --identifier "org.atelierInmu.vChewing" \
    --version "${MARKETING_VERSION}" \
    --scripts "${SCRIPTS_STAGING}" \
    --ownership recommended \
    "${OUTPUT_DIR}/vChewing-component.pkg"

# Build the distribution descriptor.
cat > "${DISTRIBUTION_XML}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-script minSpecVersion="1.0">
    <title>${INSTALLER_TITLE_KEY}</title>
    <background file="InstallerBg@2x.png" alignment="center" scaling="proportional"/>
    <background-darkAqua file="InstallerBg@2x.png" alignment="center" scaling="proportional"/>
    <options customize="never" require-scripts="true"/>
    <domains enable_anywhere="false" enable_currentUserHome="true" enable_localSystem="false"/>
    <volume-check>
        <allowed-os-versions>
            <os-version min="12.0"/>
        </allowed-os-versions>
    </volume-check>
    <welcome file="welcome.txt" mime-type="text/plain"/>
    <license file="license.txt" mime-type="text/plain"/>
    <conclusion file="conclusion.rtf" mime-type="text/rtf"/>
    <pkg-ref id="org.atelierInmu.vChewing" version="${MARKETING_VERSION}" auth="none">vChewing-component.pkg</pkg-ref>
    <choices-outline>
        <line choice="org.atelierInmu.vChewing"/>
    </choices-outline>
    <choice id="org.atelierInmu.vChewing" title="vChewing Input Method" visible="false">
        <pkg-ref id="org.atelierInmu.vChewing"/>
    </choice>
</installer-script>
EOF

# Wrap the component package into the final product archive.
if [ "${SIGN_PRODUCT}" -eq 1 ]; then
    echo "Signing product archive with Team ID ${TEAM_ID}..."
    run_with_filtered_stderr productbuild \
        --distribution "${DISTRIBUTION_XML}" \
        --resources "${RESOURCES_STAGING}" \
        --package-path "${OUTPUT_DIR}" \
        --sign "${TEAM_ID}" \
        --timestamp \
        "${OUTPUT_DIR}/${PKG_NAME}"
else
    run_with_filtered_stderr productbuild \
        --distribution "${DISTRIBUTION_XML}" \
        --resources "${RESOURCES_STAGING}" \
        --package-path "${OUTPUT_DIR}" \
        "${OUTPUT_DIR}/${PKG_NAME}"
fi

# Remove the intermediate component package; only the final product remains.
rm -f "${OUTPUT_DIR}/vChewing-component.pkg"

# Submit the signed package for notarization and staple the returned ticket.
if [ "${SIGN_PRODUCT}" -eq 1 ]; then
    echo "Submitting package for notarization..."
    xcrun notarytool submit "${OUTPUT_DIR}/${PKG_NAME}" \
        --keychain-profile "AC_PASSWORD" \
        --wait
    echo "Stapling notarization ticket..."
    xcrun stapler staple "${OUTPUT_DIR}/${PKG_NAME}"
fi

echo "Built: ${OUTPUT_DIR}/${PKG_NAME}"
echo "Marketing version: ${MARKETING_VERSION}"
echo "Build version: ${BUILD_VERSION}"
