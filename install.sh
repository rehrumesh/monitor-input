#!/usr/bin/env bash
#
# install.sh — install the `monitor-input` CLI for the Dell U2724DE.
#
# Self-contained: copy this single file to any Mac (e.g. the Mac mini) and run it.
#   curl/scp it over, then:  bash install.sh
#
# It will:
#   1. ensure Homebrew + m1ddc are present
#   2. install the `monitor-input` command into your Homebrew bin
#   3. add convenience aliases to ~/.zshrc (idempotent)
#
# The input labels are absolute (laptop = USB-C, macmini = HDMI), so the same
# tool behaves identically on every machine connected to the monitor.

set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
info() { echo "==> $*"; }

# --- 1. Homebrew -------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  die "Homebrew not found. Install it from https://brew.sh then re-run this script."
fi
BREW_BIN="$(brew --prefix)/bin"
mkdir -p "$BREW_BIN"

# --- 2. m1ddc ----------------------------------------------------------------
if ! command -v m1ddc >/dev/null 2>&1; then
  info "Installing m1ddc..."
  brew install m1ddc
else
  info "m1ddc already installed."
fi

# --- 3. monitor-input command ------------------------------------------------
TARGET="$BREW_BIN/monitor-input"
info "Installing $TARGET"
cat > "$TARGET" <<'SCRIPT'
#!/usr/bin/env bash
#
# monitor-input — switch the input source of the Dell U2724DE via DDC/CI.
#
# Inputs on this monitor:
#   laptop  / usb-c  -> VCP 0x60 value 0x19 (25)  (laptop, USB-C DisplayPort)
#   macmini / hdmi   -> VCP 0x60 value 0x11 (17)  (Mac mini, HDMI)
#
# Note: this Dell does NOT report its current input reliably over DDC (reads
# return 0 or a value unrelated to what was written), so `status`/`list` show
# the input this tool last *set* on this machine, tracked in a small state
# file. Switching with the monitor's own buttons or from another machine will
# leave that out of date. Switching (the write) is always reliable.
#
# Requires: m1ddc  (brew install m1ddc)

set -euo pipefail

MONITOR_MATCH="DELL U2724DE"   # substring matched against `m1ddc display list`
USBC_VALUE=25                  # 0x19  laptop
HDMI_VALUE=17                  # 0x11  Mac mini
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/monitor-input/last"

die() { echo "error: $*" >&2; exit 1; }

command -v m1ddc >/dev/null 2>&1 || die "m1ddc not found (brew install m1ddc)"

# Resolve the Dell's display index from the list, so it survives reordering.
find_display() {
  local line
  line=$(m1ddc display list 2>/dev/null | grep -F "$MONITOR_MATCH" | head -n1) \
    || die "monitor '$MONITOR_MATCH' not found in: m1ddc display list"
  [ -n "$line" ] || die "monitor '$MONITOR_MATCH' not found"
  # lines look like: "[2] DELL U2724DE (UUID...)"
  echo "$line" | sed -E 's/^\[([0-9]+)\].*/\1/'
}

# switch_to <name>  (name is "laptop" or "macmini")
switch_to() {
  local name="$1" val disp
  case "$name" in
    laptop)  val="$USBC_VALUE";;
    macmini) val="$HDMI_VALUE";;
    *) die "unknown input '$name'";;
  esac
  disp=$(find_display)
  m1ddc display "$disp" set input "$val" >/dev/null
  mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
  echo "$name" > "$STATE_FILE" 2>/dev/null || true
}

# Logical name of the input this tool last set on this machine, or "unknown".
current() {
  [ -f "$STATE_FILE" ] && head -n1 "$STATE_FILE" 2>/dev/null || echo "unknown"
}

status() {
  case "$(current)" in
    laptop)  echo "laptop (USB-C)   [last set by this tool]";;
    macmini) echo "macmini (HDMI)   [last set by this tool]";;
    *)       echo "unknown (no switch recorded on this machine yet)";;
  esac
}

list() {
  echo "Connected displays (m1ddc):"
  m1ddc display list 2>/dev/null | sed 's/^/  /'
  echo
  echo "Configured inputs for '$MONITOR_MATCH':"
  local cur lmark="" mmark=""
  cur=$(current)
  [ "$cur" = "laptop" ]  && lmark="  <- last set"
  [ "$cur" = "macmini" ] && mmark="  <- last set"
  printf "  %-9s %-6s %s\n" "laptop"  "USB-C" "0x19 (25)$lmark"
  printf "  %-9s %-6s %s\n" "macmini" "HDMI"  "0x11 (17)$mmark"
}

usage() {
  cat <<EOF
usage: monitor-input <command>

  laptop    switch Dell to the laptop   (USB-C)
  macmini   switch Dell to the Mac mini (HDMI)
  toggle    switch to whichever input was not last set
  status    show the input this tool last set
  list      list connected displays and configured inputs
  help      show this message
EOF
}

cmd="${1:-help}"
case "$cmd" in
  laptop|usbc|usb-c)          switch_to laptop;  echo "-> laptop (USB-C)";;
  macmini|mac-mini|hdmi|mini) switch_to macmini; echo "-> macmini (HDMI)";;
  toggle)
    if [ "$(current)" = "laptop" ]; then
      switch_to macmini; echo "-> macmini (HDMI)"
    else
      switch_to laptop;  echo "-> laptop (USB-C)"
    fi
    ;;
  status|get)  status;;
  list|ls)     list;;
  help|-h|--help) usage;;
  *) usage; exit 1;;
esac
SCRIPT
chmod +x "$TARGET"

# --- 4. zsh aliases (idempotent) ---------------------------------------------
ZSHRC="$HOME/.zshrc"
MARKER="# Dell U2724DE input switching (monitor-input CLI)"
if [ -f "$ZSHRC" ] && grep -qF "$MARKER" "$ZSHRC"; then
  info "Aliases already present in $ZSHRC"
else
  info "Adding aliases to $ZSHRC"
  cat >> "$ZSHRC" <<EOF

$MARKER
alias mlaptop='monitor-input laptop'      # switch Dell to the laptop  (USB-C)
alias mmini='monitor-input macmini'       # switch Dell to the Mac mini (HDMI)
alias mtoggle='monitor-input toggle'      # flip to the other input
alias mstatus='monitor-input status'      # show current input
EOF
fi

echo
info "Done. Open a new terminal (or: source ~/.zshrc) to use the aliases."
echo "    monitor-input status   |   mlaptop  mmini  mtoggle  mstatus"
