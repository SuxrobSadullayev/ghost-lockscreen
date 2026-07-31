#!/bin/bash
# ============================================================
# diagnose.sh - read-only diagnostic for School21 computers
# that auto-logout the session after 30 minutes of inactivity.
#
# Determines WHICH mechanism is responsible and verifies the
# prerequisites of the 'lockscreen' tool.
#
# SAFE / NON-DESTRUCTIVE:
#   * everything here is read-only checks
#   * the only two "writes" are:
#       1) gsettings set idle-delay to its CURRENT value (no-op)
#       2) a 2-second systemd idle inhibitor
#   * no settings are changed, no screen is locked
# No root required. Bash 4+.
# ============================================================

LOG_FILE="$HOME/lockscreen_diagnose.txt"
USER_NAME="${USER:-$(whoami 2>/dev/null || echo unknown)}"

# Verdict variables collected along the way
IDLE_ACTION=""
IDLE_ACTION_SEC=""
SESSION_ID=""
GSETTINGS_WRITE="unknown"
INHIBIT_RESULT="unknown"

# Print to stdout AND append to the log file
log() {
    echo "$*" | tee -a "$LOG_FILE"
}

# Read a KEY=VALUE setting from logind.conf + drop-ins (later files win)
parse_logind_conf() {
    local key="$1"
    local val=""
    local f line key_part
    for f in /etc/systemd/logind.conf /etc/systemd/logind.conf.d/*.conf /usr/lib/systemd/logind.conf.d/*.conf; do
        [ -e "$f" ] || continue
        while IFS= read -r line; do
            case "$line" in
                \#*|"") continue ;;
            esac
            key_part="${line%%=*}"
            key_part="${key_part// /}"
            if [ "$key_part" = "$key" ]; then
                val="${line#*=}"
                val="${val#"${val%%[![:space:]]*}"}"
                val="${val%"${val##*[![:space:]]}"}"
            fi
        done < "$f"
    done
    echo "$val"
}

# Fresh log file on every run
: > "$LOG_FILE"

log "============================================================"
log "lockscreen-diagnose - School21 30-min auto-logout diagnostic"
log "Date: $(date '+%Y-%m-%d %H:%M:%S')   User: $USER_NAME"
log "Log file: $LOG_FILE"
log "============================================================"
log ""

# ────────────────────────────────────────────────────────────────
# [1/6] Environment
# ────────────────────────────────────────────────────────────────
log "=== [1/6] Environment ==="
log "XDG_SESSION_TYPE    : ${XDG_SESSION_TYPE:-<unset>}"
log "WAYLAND_DISPLAY     : ${WAYLAND_DISPLAY:-<unset>}"
log "XDG_CURRENT_DESKTOP : ${XDG_CURRENT_DESKTOP:-<unset>}"
log "DISPLAY             : ${DISPLAY:-<unset>}"
if command -v gnome-shell >/dev/null 2>&1; then
    log "gnome-shell         : $(gnome-shell --version 2>&1)"
else
    log "gnome-shell         : NOT FOUND"
fi
log "OS                  : $(grep PRETTY_NAME /etc/os-release 2>/dev/null || echo '<unreadable>')"
log "Kernel              : $(uname -r)"
log "Uptime              : $(uptime 2>/dev/null || echo '<n/a>')"
log "who:"
log "$(who 2>/dev/null || echo '  <n/a>')"
log ""

# ────────────────────────────────────────────────────────────────
# [2/6] systemd-logind investigation (the key part)
# ────────────────────────────────────────────────────────────────
log "=== [2/6] systemd-logind investigation ==="
log "--- 'systemctl show systemd-logind' — Idle-related lines ---"
LOGIND_IDLE=$(systemctl show systemd-logind 2>/dev/null | grep -i idle)
if [ -n "$LOGIND_IDLE" ]; then
    log "$LOGIND_IDLE"
else
    log "  (no Idle* properties found - systemd-logind not running or not accessible)"
fi
IDLE_ACTION=$(systemctl show systemd-logind -p IdleAction --value 2>/dev/null)
[ -z "$IDLE_ACTION" ] && IDLE_ACTION=$(systemctl show systemd-logind -p IdleAction 2>/dev/null | cut -d= -f2-)
IDLE_ACTION_SEC=$(systemctl show systemd-logind -p IdleActionSec --value 2>/dev/null)
[ -z "$IDLE_ACTION_SEC" ] && IDLE_ACTION_SEC=$(systemctl show systemd-logind -p IdleActionSec 2>/dev/null | cut -d= -f2-)
# Newer systemd no longer exposes these on the unit - fall back to the config files
if [ -z "$IDLE_ACTION" ]; then
    IDLE_ACTION=$(parse_logind_conf IdleAction)
    log "  (IdleAction from logind.conf/drop-ins)"
fi
if [ -z "$IDLE_ACTION_SEC" ]; then
    IDLE_ACTION_SEC=$(parse_logind_conf IdleActionSec)
    log "  (IdleActionSec from logind.conf/drop-ins)"
fi
log "  (parsed: IdleAction=${IDLE_ACTION:-<unset>}, IdleActionSec=${IDLE_ACTION_SEC:-<unset>})"
log ""

log "--- /etc/systemd/logind.conf (active, comments stripped) ---"
CONF=$(grep -v '^#' /etc/systemd/logind.conf 2>/dev/null | grep -v '^$')
if [ -n "$CONF" ]; then
    log "$CONF"
else
    log "  (no file or all lines are comments = pure defaults)"
fi
log ""

log "--- drop-ins ---"
for d in /etc/systemd/logind.conf.d /usr/lib/systemd/logind.conf.d; do
    if [ -d "$d" ]; then
        log "  $d/:"
        log "$(ls -la "$d" 2>/dev/null)"
        for f in "$d"/*.conf; do
            [ -e "$f" ] || continue
            log "  --- $f ---"
            log "$(grep -v '^#' "$f" 2>/dev/null | grep -v '^$')"
        done
    else
        log "  $d/ : (not present)"
    fi
done
log ""

log "--- loginctl list-sessions (full) ---"
log "$(loginctl list-sessions 2>&1 || echo '  (loginctl failed or not available)')"
log ""

# Find this user's session (with fallbacks for older systemd without TYPE column)
if command -v loginctl >/dev/null 2>&1; then
    SESSION_ID=$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$USER_NAME" '$3==u && $6=="user" {print $1; exit}')
    [ -z "$SESSION_ID" ] && SESSION_ID=$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$USER_NAME" '$3==u {print $1; exit}')
    [ -z "$SESSION_ID" ] && SESSION_ID=$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$(id -u 2>/dev/null)" '$2==u {print $1; exit}')
fi
if [ -n "$SESSION_ID" ]; then
    log "--- this user's session: '$SESSION_ID' ---"
    log "$(loginctl show-session "$SESSION_ID" -p IdleHint -p IdleSinceHint -p Active -p LockedHint 2>&1)"
    log "  (IdleHint=no  -> an idle inhibitor is active; the lockscreen tool is running)"
    log "  (IdleHint=yes -> logind considers this session idle; nothing is inhibiting)"
    log ""
    log "--- loginctl show-user '$USER_NAME' ---"
    log "$(loginctl show-user "$USER_NAME" -p IdleHint -p IdleSinceHint 2>&1)"
else
    log "--- this user's session: NOT FOUND (loginctl session listing unavailable here) ---"
    log "  (on the School21 machine this should normally appear; see list above)"
fi
log ""

# ────────────────────────────────────────────────────────────────
# [3/6] dconf locks & gsettings
# ────────────────────────────────────────────────────────────────
log "=== [3/6] dconf locks & gsettings ==="
log "--- /etc/dconf/db/ ---"
log "$(ls -la /etc/dconf/db/ 2>/dev/null || echo '  (no /etc/dconf/db/ - no system dconf database)')"
log ""
log "--- /etc/dconf/db/local.d/locks ---"
if [ -d /etc/dconf/db/local.d/locks ]; then
    log "$(ls -la /etc/dconf/db/local.d/locks/)"
    for f in /etc/dconf/db/local.d/locks/*; do
        [ -e "$f" ] || continue
        log "  --- contents of $f ---"
        log "$(cat "$f" 2>/dev/null)"
    done
else
    log "  (no /etc/dconf/db/local.d/locks/ directory - no local dconf locks)"
fi
log ""

log "--- gsettings write test (no-op: set idle-delay to its CURRENT value) ---"
if command -v gsettings >/dev/null 2>&1; then
    CUR_DELAY=$(gsettings get org.gnome.desktop.session idle-delay 2>/dev/null)
    if [ -n "$CUR_DELAY" ]; then
        log "current idle-delay : $CUR_DELAY"
        if gsettings set org.gnome.desktop.session idle-delay "$CUR_DELAY" 2>/dev/null; then
            log "WRITE TEST: OK - gsettings set succeeded (same value, no change made)"
            log "            -> gsettings is NOT dconf-locked"
            GSETTINGS_WRITE="ok"
        else
            log "WRITE TEST: BLOCKED - gsettings set failed"
            log "            -> dconf lock present; old gsettings approach cannot work"
            GSETTINGS_WRITE="blocked"
        fi
    else
        log "GET FAILED: 'gsettings get org.gnome.desktop.session idle-delay' returned nothing"
        log "            -> schema missing, or no session DBus bus; writes cannot be tested"
        GSETTINGS_WRITE="failed"
    fi
else
    log "gsettings           : NOT FOUND"
    GSETTINGS_WRITE="failed"
fi
log ""

# ────────────────────────────────────────────────────────────────
# [4/6] systemd-inhibit availability & permission
# ────────────────────────────────────────────────────────────────
log "=== [4/6] systemd-inhibit availability & permission ==="
if command -v systemd-inhibit >/dev/null 2>&1; then
    log "systemd-inhibit     : $(systemd-inhibit --version 2>&1 | head -n 1)"
    log ""
    log "--- Permission test: register a 2-second idle inhibitor (safe, non-destructive) ---"
    if command -v timeout >/dev/null 2>&1; then
        INHIBIT_OUT=$(timeout 10 systemd-inhibit --what=idle --mode=block --why="lockscreen-diagnose" sleep 2 2>&1)
    else
        INHIBIT_OUT=$(systemd-inhibit --what=idle --mode=block --why="lockscreen-diagnose" sleep 2 2>&1)
    fi
    INHIBIT_RC=$?
    if [ "$INHIBIT_RC" -eq 0 ]; then
        log "INHIBIT_OK: idle inhibitor registered (2s) - the systemd-inhibit approach will work"
        log "  output: ${INHIBIT_OUT:-<none>}"
        INHIBIT_RESULT="ok"
    else
        log "INHIBIT_FAILED: cannot register idle inhibitor (exit ${INHIBIT_RC})"
        log "  output: ${INHIBIT_OUT:-<none>}"
        log "  (expected here if this is not a real logged-in desktop session)"
        INHIBIT_RESULT="failed"
    fi
else
    log "systemd-inhibit     : NOT FOUND"
    log "  -> the lockscreen tool will fall back to the old gsettings approach"
    INHIBIT_RESULT="unavailable"
fi
log ""

# ────────────────────────────────────────────────────────────────
# [5/6] Lock command availability
# ────────────────────────────────────────────────────────────────
log "=== [5/6] Lock command availability ==="
for c in loginctl gdbus gnome-screensaver-command; do
    if command -v "$c" >/dev/null 2>&1; then
        log "  $c : $(command -v "$c")"
    else
        log "  $c : NOT FOUND"
    fi
done
log ""
if [ -n "$SESSION_ID" ]; then
    log "Session id the lockscreen tool would lock: $SESSION_ID"
    log "  (i.e. 'loginctl lock-session $SESSION_ID')"
else
    log "Session id the lockscreen tool would lock: <unknown>"
fi
log ""

# ────────────────────────────────────────────────────────────────
# [6/6] Verdict
# ────────────────────────────────────────────────────────────────
log "=== [6/6] Verdict ==="
log ""

if [ "$IDLE_ACTION" = "lock" ] || [ "$IDLE_ACTION" = "logout" ]; then
    log "VERDICT 1: logind IS configured to act after idle:"
    if [ -n "$IDLE_ACTION_SEC" ]; then
        log "           IdleAction=${IDLE_ACTION}, IdleActionSec=${IDLE_ACTION_SEC}"
    else
        log "           IdleAction=${IDLE_ACTION}, IdleActionSec=<unset> (default is 30min)"
    fi
    log "           -> systemd-logind is very likely the 30-minute auto-logout mechanism"
    if [ "$INHIBIT_RESULT" = "ok" ]; then
        log "VERDICT 2: systemd-inhibit works for this user"
        log "           -> 'lockscreen <time>' SHOULD stop the logout"
    else
        log "VERDICT 2: systemd-inhibit did NOT register (INHIBIT_FAILED)"
        log "           -> the lockscreen tool will fall back to the old gsettings approach"
        log "              and may NOT stop the logout - note this clearly"
    fi
else
    log "VERDICT 1: logind IdleAction is '${IDLE_ACTION:-<not set>}' (default = ignore)"
    log "           -> logind idle action is NOT the mechanism"
    log "              (look at GNOME screensaver / power settings instead)"
fi

case "$GSETTINGS_WRITE" in
    ok)
        log "VERDICT 3: gsettings writes are allowed"
        log "           -> old gsettings approach still works on this machine"
        ;;
    blocked)
        log "VERDICT 3: gsettings write is BLOCKED by a dconf lock"
        log "           -> old gsettings approach CANNOT work; confirms the rewrite was needed"
        ;;
    failed)
        log "VERDICT 3: gsettings could not be tested (schema missing / no session bus)"
        ;;
esac

log ""
if [ "$INHIBIT_RESULT" = "ok" ] && { [ "$IDLE_ACTION" = "lock" ] || [ "$IDLE_ACTION" = "logout" ]; }; then
    log "SUMMARY: auto-logout is handled by systemd-logind, and the new"
    log "         systemd-inhibit approach should work on this machine."
elif [ "$INHIBIT_RESULT" != "ok" ]; then
    log "SUMMARY: an idle inhibitor cannot be registered here - the lockscreen tool"
    log "         will use the old gsettings fallback; effectiveness is uncertain."
else
    log "SUMMARY: no logind idle action configured - the mechanism is elsewhere"
    log "         (GNOME screensaver / power settings); check section [3/6]."
fi
log ""
log "Done. Output also saved to: $LOG_FILE"
