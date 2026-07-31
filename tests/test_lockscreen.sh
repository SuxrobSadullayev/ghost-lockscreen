#!/bin/bash

# ============================================================
# test_lockscreen.sh - tests for the lockscreen tool
# Uses stub binaries in a temp dir; no real side effects.
# Run: bash tests/test_lockscreen.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCKSCREEN="$SCRIPT_DIR/../lockscreen"

TEST_DIR=$(mktemp -d)
BIN_DIR="$TEST_DIR/bin"
HOME_DIR="$TEST_DIR/home"
mkdir -p "$BIN_DIR" "$HOME_DIR"

export HOME="$HOME_DIR"
export USER="testuser"
export DISPLAY=":0"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/99999/bus"
export STUB_LOG="$TEST_DIR/stub.log"

PASS=0
FAIL=0

ok()  { echo "PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ─── stub helpers ─────────────────────────────────────────────────────────────

record() {
    echo "$(basename "$0") $*" >> "$STUB_LOG"
}

cat > "$BIN_DIR/gsettings" <<'EOF'
#!/bin/bash
echo "gsettings $*" >> "$STUB_LOG"
case "$1" in
    get)
        case "$3" in
            idle-delay)    echo "uint32 1800" ;;
            lock-enabled)  echo "true" ;;
        esac
        ;;
esac
EOF

cat > "$BIN_DIR/loginctl" <<'EOF'
#!/bin/bash
echo "loginctl $*" >> "$STUB_LOG"
case "$1" in
    list-sessions)
        echo " 2 1000 testuser seat0 4273 user tty2 no -"
        echo " 3 1000 testuser - 4884 manager - no -"
        ;;
esac
exit 0
EOF

cat > "$BIN_DIR/systemd-inhibit" <<'EOF'
#!/bin/bash
echo "systemd-inhibit $*" >> "$STUB_LOG"
/usr/bin/sleep 5
exit 0
EOF

cat > "$BIN_DIR/sleep" <<'EOF'
#!/bin/bash
echo "sleep $*" >> "$STUB_LOG"
if [ "${1:-0}" -ge 1000 ] 2>/dev/null; then
    /usr/bin/sleep 5
else
    /usr/bin/sleep 0.2
fi
exit 0
EOF

cat > "$BIN_DIR/nohup" <<'EOF'
#!/bin/bash
echo "nohup $*" >> "$STUB_LOG"
exec "$@"
EOF

for stub in notify-send gdbus xset; do
    cat > "$BIN_DIR/$stub" <<'EOF'
#!/bin/bash
echo "$(basename "$0") $*" >> "$STUB_LOG"
exit 0
EOF
done

chmod +x "$BIN_DIR"/*
export PATH="$BIN_DIR:$PATH"

# ─── tests ────────────────────────────────────────────────────────────────────

# Test 1: lockscreen 6h — saves settings, starts inhibitor, locks, starts timer
rm -f "$STUB_LOG"
OUT=$("$LOCKSCREEN" 6h 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then ok "1. lockscreen 6h exits 0"; else bad "1. lockscreen 6h exit=$RC out=$OUT"; fi
grep -q "gsettings get org.gnome.desktop.session idle-delay" "$STUB_LOG" && ok "1. settings saved (gsettings get)" || bad "1. settings not saved"
grep -q "systemd-inhibit --what=idle --mode=block" "$STUB_LOG" && ok "1. inhibitor started with --what=idle" || bad "1. inhibitor not started"
grep -q "loginctl lock-session 2" "$STUB_LOG" && ok "1. screen locked via loginctl (session 2)" || bad "1. screen not locked (loginctl)"
[ -f "$HOME_DIR/.lockscreen_timer" ] && ok "1. timer file exists" || bad "1. timer file missing"
[ -f "$HOME_DIR/.lockscreen_inhibitor_pid" ] && ok "1. inhibitor pid file exists" || bad "1. inhibitor pid file missing"
echo "$OUT" | grep -q "kept alive for 6h" && ok "1. output shows 'kept alive for 6h'" || bad "1. output wrong: $OUT"

# Test 2: status shows running timer + inhibitor
OUT=$("$LOCKSCREEN" status 2>&1)
echo "$OUT" | grep -q "Timer      : RUNNING" && ok "2. status shows timer RUNNING" || bad "2. status timer: $OUT"
echo "$OUT" | grep -q "Inhibitor  : RUNNING" && ok "2. status shows inhibitor RUNNING" || bad "2. status inhibitor: $OUT"

# Test 3: lockscreen off — restores settings, cleans files
OUT=$("$LOCKSCREEN" off 2>&1)
grep -q "gsettings set org.gnome.desktop.session idle-delay 1800" "$STUB_LOG" && ok "3. settings restored (idle-delay 1800)" || bad "3. settings not restored"
[ ! -f "$HOME_DIR/.lockscreen_timer" ] && ok "3. timer file removed" || bad "3. timer file still exists"
[ ! -f "$HOME_DIR/.lockscreen_inhibitor_pid" ] && ok "3. inhibitor file removed" || bad "3. inhibitor file still exists"

# Test 4: time parsing — 30m -> 1800s, 90m -> 5400s
rm -f "$STUB_LOG"
"$LOCKSCREEN" off >/dev/null 2>&1
"$LOCKSCREEN" 30m >/dev/null 2>&1
grep -q "sleep 1800" "$STUB_LOG" && ok "4. 30m parses to 1800s" || bad "4. 30m -> not 1800s: $(grep 'sleep ' "$STUB_LOG")"
"$LOCKSCREEN" off >/dev/null 2>&1
rm -f "$STUB_LOG"
"$LOCKSCREEN" 90m >/dev/null 2>&1
grep -q "sleep 5400" "$STUB_LOG" && ok "4. 90m parses to 5400s" || bad "4. 90m -> not 5400s: $(grep 'sleep ' "$STUB_LOG")"
"$LOCKSCREEN" off >/dev/null 2>&1

# Test 5: dry-run — no side effects, prints plan
rm -f "$STUB_LOG"
OUT=$("$LOCKSCREEN" dry-run 6h 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then ok "5. dry-run exits 0"; else bad "5. dry-run exit=$RC"; fi
echo "$OUT" | grep -q "dry-run: nothing was executed" && ok "5. dry-run announces no execution" || bad "5. dry-run message: $OUT"
! grep -q "systemd-inhibit" "$STUB_LOG" && ok "5. no inhibitor started" || bad "5. inhibitor started in dry-run"
! grep -q "lock-session" "$STUB_LOG" && ok "5. no lock performed" || bad "5. lock performed in dry-run"
[ ! -f "$HOME_DIR/.lockscreen_timer" ] && ok "5. no timer file created" || bad "5. timer file created in dry-run"

# Test 6: invalid argument — error + non-zero exit
if "$LOCKSCREEN" badarg >/dev/null 2>&1; then
    bad "6. badarg should exit non-zero"
else
    ok "6. badarg exits non-zero"
fi

# Test 7: no argument — usage, exit 0
"$LOCKSCREEN" >/dev/null 2>&1
RC=$?
if [ "$RC" -eq 0 ]; then ok "7. no args exits 0 (usage)"; else bad "7. no args exit=$RC"; fi

# ─── cleanup ──────────────────────────────────────────────────────────────────

# Kill any still-running stubs (should not exist, but be safe)
[ -f "$HOME_DIR/.lockscreen_inhibitor_pid" ] && kill "$(cat "$HOME_DIR/.lockscreen_inhibitor_pid")" 2>/dev/null
[ -f "$HOME_DIR/.lockscreen_timer" ] && kill "$(cat "$HOME_DIR/.lockscreen_timer")" 2>/dev/null
rm -rf "$TEST_DIR"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
