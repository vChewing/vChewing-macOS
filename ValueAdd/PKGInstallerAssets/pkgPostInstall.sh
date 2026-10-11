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

# Post-swap termination of stale instances (begin).
#
# This is the guarantee, and the reason it sits here rather than in the
# pre-install script: the payload is extracted between the two scripts, so by
# now the new bundle is on disk. IMK launches input methods on demand from
# whichever bundle is registered at that moment, so killing before the payload
# lands only prompts a relaunch of the old code under a new PID - an instance
# that then slips past every later check. Retiring the old instances after the
# swap is what makes every later launch come from the new code. The pass also
# runs before the input source is registered, since registration itself may
# pull the input method up. The postcondition is "the captured PIDs are gone",
# deliberately not "no process exists": IMK relaunches on demand, so the latter
# could never hold.
#
# Only the console user's processes are targeted: the instances that matter
# belong to the GUI session whose bundle we just replaced, and a root-run
# install (e.g. Homebrew's `pkg` stanza) must not retire the instances of other
# logged-in users.
#
# `pgrep -x` matches the executable's name (what `killall` uses) and thus also
# catches instances launched from a `.appTrashed` copy of an older bundle; the
# path pattern covers a process whose recorded name was altered or truncated.
#
# This block is self-contained - it only reads ${TERMINATION_NAME} (which
# defaults to ${IME_EXECUTABLE}) and ${login_user}, both defined above - so that
# the local probe harness can extract and source it verbatim; see the Phase 300
# research note.
TERMINATION_NAME="${TERMINATION_NAME:-${IME_EXECUTABLE}}"
TERMINATION_POLL_INTERVAL=0.1
TERMINATION_GRACE_TICKS=30 # 3.0s of polling after SIGTERM
TERMINATION_FORCE_TICKS=30 # 3.0s of polling after SIGKILL

process_is_alive() {
    [ -n "$1" ] || return 1
    /bin/ps -o pid= -p "$1" 2>/dev/null | /usr/bin/grep -q '[0-9]'
}

# Echo the PIDs in $1 that are still alive after at most $2 polls.
wait_until_vacant() {
    pending="$1"
    ticks="$2"
    tick=0
    while [ -n "${pending}" ]; do
        remaining=""
        for pid in ${pending}; do
            if process_is_alive "${pid}"; then
                remaining="${remaining}${remaining:+ }${pid}"
            fi
        done
        pending="${remaining}"
        [ -n "${pending}" ] || break
        if [ "${tick}" -ge "${ticks}" ]; then
            break
        fi
        sleep "${TERMINATION_POLL_INTERVAL}"
        tick=$((tick + 1))
    done
    printf '%s' "${pending}"
}

terminate_stale_instances() {
    pending=""
    for pid in $(/usr/bin/pgrep -x "${TERMINATION_NAME}" 2>/dev/null) \
        $(/usr/bin/pgrep -f "Contents/MacOS/${TERMINATION_NAME}" 2>/dev/null); do
        case "${pid}" in '' | 1 | "$$") continue ;; esac
        case "${pending} " in *"${pid} "*) continue ;; esac
        owner=$(/bin/ps -o user= -p "${pid}" 2>/dev/null | /usr/bin/tr -d ' ')
        [ "${owner}" = "${login_user}" ] || continue
        pending="${pending}${pending:+ }${pid}"
    done

    captured=$(printf '%s' "${pending}" | /usr/bin/tr ' ' ',')
    escalated=false
    surviving=""
    if [ -n "${pending}" ]; then
        for pid in ${pending}; do
            /bin/kill -TERM "${pid}" 2>/dev/null || true
        done
        surviving=$(wait_until_vacant "${pending}" "${TERMINATION_GRACE_TICKS}")
        if [ -n "${surviving}" ]; then
            escalated=true
            for pid in ${surviving}; do
                /bin/kill -KILL "${pid}" 2>/dev/null || true
            done
            surviving=$(wait_until_vacant "${surviving}" "${TERMINATION_FORCE_TICKS}")
        fi
    fi

    if [ -n "${surviving}" ]; then
        result=stuck
    else
        result=vacated
    fi
    printf 'Terminate: reason=postSwap captured=[%s] escalated=%s result=%s surviving=[%s]\n' \
        "${captured}" "${escalated}" "${result}" \
        "$(printf '%s' "${surviving}" | /usr/bin/tr ' ' ',')"
}

terminate_stale_instances
# End of post-swap termination helper.

# Terminate the text input menu agent (TextInputMenuAgent) before registering the
# input method: the register step must wait for the kill to finish (regardless of
# its outcome) plus 0.5s, so the relaunched agent can pick up the newly registered
# input source without requiring the user to log out and back in. Only
# TextInputMenuAgent is targeted: killing imklaunchagent would cut the currently
# active client app off from every input method until that app is restarted, while
# TextInputSwitcher is a pure UI helper whose termination has no effect. This
# agent belongs to the console user's GUI session, so the kill is performed with
# the console user's privileges when the installer runs as root. The agent may not
# exist on older macOS versions; ignore any failure.
if [ "$(id -u)" -eq 0 ]; then
    su - "${login_user}" -c "/usr/bin/killall TextInputMenuAgent" 2>/dev/null || true
else
    /usr/bin/killall TextInputMenuAgent 2>/dev/null || true
fi
sleep 0.5

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
