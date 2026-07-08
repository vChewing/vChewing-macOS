#!/bin/sh
# BuildPKG.sh
# Reproduces the vChewing.pkgproj workflow using pkgbuild + productbuild.
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

# Allow command-line overrides: BuildPKG.sh [marketing-version] [build-version]
if [ -n "$1" ]; then
    MARKETING_VERSION="$1"
fi
if [ -n "$2" ]; then
    BUILD_VERSION="$2"
fi

TARGET='vChewing'
IME_APP="Build/Products/Release/${TARGET}.app"
KEYLAYOUT_BUNDLE="Sources/vChewingIME_macOS/Resources/vChewingKeyLayout.bundle"
KEYLAYOUT_RESOURCES="${KEYLAYOUT_BUNDLE}/Contents/Resources"
ASSETS_DIR="ValueAdd/PKGInstallerAssets"
OUTPUT_DIR="Build"
PKG_NAME="${TARGET}-macOS-${MARKETING_VERSION}-unsigned.pkg"

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
run_with_filtered_stderr productbuild \
    --distribution "${DISTRIBUTION_XML}" \
    --resources "${RESOURCES_STAGING}" \
    --package-path "${OUTPUT_DIR}" \
    "${OUTPUT_DIR}/${PKG_NAME}"

# Remove the intermediate component package; only the final product remains.
rm -f "${OUTPUT_DIR}/vChewing-component.pkg"

echo "Built: ${OUTPUT_DIR}/${PKG_NAME}"
echo "Marketing version: ${MARKETING_VERSION}"
echo "Build version: ${BUILD_VERSION}"
