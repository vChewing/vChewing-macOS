#!/bin/sh

TARGET='vChewing'

# Determine the console user: the person who will actually use the input method.
login_user=$(/usr/bin/stat -f%Su /dev/console)
user_home=$(eval echo "~${login_user}")
user_trash="${user_home}/.Trash"

# Terminate any running vChewing processes so bundles are not locked.
killall "${TARGET}" 2>/dev/null || true
killall "${TARGET}PhraseEditor" 2>/dev/null || true

# Generate a timestamped destination name for an existing .app bundle.
timestamped_name() {
    src_name=$(basename "$1")
    timestamp=$(date +%Y-%m-%dT%H-%M-%S)
    dst_name="${src_name%.app}-${timestamp}.appTrashed"
    dst_dir="$2"
    dst_path="${dst_dir}/${dst_name}"

    counter=1
    while [ -e "${dst_path}" ]; do
        dst_name="${src_name%.app}-${timestamp}-${counter}.appTrashed"
        dst_path="${dst_dir}/${dst_name}"
        counter=$((counter + 1))
    done

    printf '%s' "${dst_path}"
}

# Move an existing user-home .app bundle into the console user's Trash.
# When the installer is running as root, the move is performed via su so the
# trashed item remains owned by the console user. This avoids leaving stale
# .appTrashed bundles in ~/Library/Input Methods.
trash_user_bundle() {
    src_path="$1"
    [ -e "${src_path}" ] || return 0

    mkdir -p "${user_trash}"
    chown "${login_user}:" "${user_trash}" 2>/dev/null || true

    dst_path=$(timestamped_name "${src_path}" "${user_trash}")

    if [ "$(id -u)" -eq 0 ]; then
        # Run the move as the console user so ownership stays correct.
        escaped_src=$(printf '%q' "${src_path}")
        escaped_dst=$(printf '%q' "${dst_path}")
        su - "${login_user}" -c "mv ${escaped_src} ${escaped_dst}" 2>/dev/null || true
    else
        mv "${src_path}" "${dst_path}" 2>/dev/null || true
    fi
}

# Rename an existing system-level .app bundle in place with a timestamped
# .appTrashed suffix. If the current process lacks write permission, request
# administrator credentials via osascript. System bundles are not moved into
# the user Trash to avoid root/user Trash directory mismatches.
rename_system_bundle() {
    src_path="$1"
    [ -e "${src_path}" ] || return 0

    src_dir=$(dirname "${src_path}")
    dst_path=$(timestamped_name "${src_path}" "${src_dir}")

    if mv "${src_path}" "${dst_path}" 2>/dev/null; then
        return 0
    fi

    # Not enough permission: ask the user for admin.
    if [ "$(id -u)" -ne 0 ]; then
        escaped_src=$(printf '%q' "${src_path}")
        escaped_dst=$(printf '%q' "${dst_path}")
        osascript -e "do shell script \"mv ${escaped_src} ${escaped_dst}\" with administrator privileges" 2>/dev/null || true
    fi
}

# Remove other vChewing artifacts (keyboard layouts). No admin prompt is used.
remove_artifacts() {
    for item in "$1"/${TARGET}*; do
        [ -e "${item}" ] || continue
        rm -rf "${item}" 2>/dev/null || true
    done
}

# Handle any vChewing input method bundle left in the system directory.
rename_system_bundle "/Library/Input Methods/${TARGET}.app"

# When running as root, also remove old vChewing keyboard layout artifacts in
# system directories. We do not prompt for admin here.
if [ "$(id -u)" -eq 0 ]; then
    remove_artifacts "/Library/Keyboard Layouts"
fi

# Trash the old vChewing IME bundle in the current user's home directory and
# remove old keyboard layout artifacts there.
trash_user_bundle "${user_home}/Library/Input Methods/${TARGET}.app"
remove_artifacts "${user_home}/Library/Keyboard Layouts"

exit 0
