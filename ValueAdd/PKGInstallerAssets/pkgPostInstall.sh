#!/bin/sh

TARGET='vChewing'
IME_EXECUTABLE="${TARGET}"

# Determine the console user and their home directory.
login_user=$(/usr/bin/stat -f%Su /dev/console)
user_home=$(eval echo "~${login_user}")
login_group=$(id -gn "${login_user}")

user_ime_path="${user_home}/Library/Input Methods/${TARGET}.app"
user_kb_dir="${user_home}/Library/Keyboard Layouts"

# If the package payload landed in the system Library (e.g. an older installer
# workflow or an explicit root target), move it to the current user's home.
sys_ime_path="/Library/Input Methods/${TARGET}.app"
if [ -e "${sys_ime_path}" ]; then
    mkdir -p "${user_home}/Library/Input Methods"
    rm -rf "${user_ime_path}.moved" 2>/dev/null || true
    mv "${sys_ime_path}" "${user_ime_path}" 2>/dev/null || cp -R "${sys_ime_path}" "${user_ime_path}"
    rm -rf "${sys_ime_path}" 2>/dev/null || true
fi

for sys_item in /Library/Keyboard\ Layouts/"${TARGET}"*; do
    [ -e "${sys_item}" ] || continue
    item_name=$(basename "${sys_item}")
    mkdir -p "${user_kb_dir}"
    rm -rf "${user_kb_dir}/${item_name}.moved" 2>/dev/null || true
    mv "${sys_item}" "${user_kb_dir}/${item_name}" 2>/dev/null || cp -R "${sys_item}" "${user_kb_dir}/${item_name}"
    rm -rf "${sys_item}" 2>/dev/null || true
done

# Ensure the installed files are owned by the console user so they have full
# control, even when the installer was executed with administrator privileges.
if [ -d "${user_ime_path}" ]; then
    chown -R "${login_user}:${login_group}" "${user_ime_path}" || true
fi

for user_kb_item in "${user_kb_dir}"/"${TARGET}"*; do
    [ -e "${user_kb_item}" ] || continue
    chown -R "${login_user}:${login_group}" "${user_kb_item}" || true
done

chown "${login_user}:${login_group}" "${user_home}/Library/Input Methods" 2>/dev/null || true
chown "${login_user}:${login_group}" "${user_kb_dir}" 2>/dev/null || true

# Register the input method by running the IME executable with the "install"
# argument. This must run as the console user, not as root.
register_script=$(mktemp /tmp/vchewing-register.XXXXXX.sh)
cat > "${register_script}" <<EOF
#!/bin/sh
exec "${user_ime_path}/Contents/MacOS/${IME_EXECUTABLE}" install
EOF
chmod +x "${register_script}"

if [ "$(id -u)" -eq 0 ]; then
    chown "${login_user}" "${register_script}" || true
    su - "${login_user}" -c "${register_script}" || true
else
    "${register_script}" || true
fi

rm -f "${register_script}"

exit 0
