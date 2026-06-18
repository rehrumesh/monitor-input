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
# Requires: m1ddc  (brew install m1ddc)

set -euo pipefail

MONITOR_MATCH="DELL U2724DE"   # substring matched against `m1ddc display list`
USBC_VALUE=25                  # 0x19  laptop
HDMI_VALUE=17                  # 0x11  Mac mini

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

set_input() {
  local val="$1" disp
  disp=$(find_display)
  m1ddc display "$disp" set input "$val" >/dev/null
}

get_input() {
  local disp; disp=$(find_display)
  m1ddc display "$disp" get input 2>/dev/null
}

status() {
  # The U2724DE reports unreliably; sample a few times and take a non-zero read.
  local v i
  for i in 1 2 3 4 5 6; do
    v=$(get_input || true)
    [ -n "${v:-}" ] && [ "$v" != "0" ] && break
    sleep 0.2
  done
  case "${v:-}" in
    "$USBC_VALUE") echo "laptop (USB-C, $v)";;
    "$HDMI_VALUE") echo "macmini (HDMI, $v)";;
    ""|0)          echo "unknown (monitor did not report)";;
    *)             echo "other (value $v)";;
  esac
}

usage() {
  cat <<EOF
usage: monitor-input <command>

  laptop    switch Dell to the laptop   (USB-C)
  macmini   switch Dell to the Mac mini (HDMI)
  toggle    switch to whichever input is not active
  status    show the current input
  help      show this message
EOF
}

cmd="${1:-help}"
case "$cmd" in
  laptop|usbc|usb-c)          set_input "$USBC_VALUE"; echo "-> laptop (USB-C)";;
  macmini|mac-mini|hdmi|mini) set_input "$HDMI_VALUE"; echo "-> macmini (HDMI)";;
  toggle)
    cur=$(status)
    if [[ "$cur" == laptop* ]]; then
      set_input "$HDMI_VALUE"; echo "-> macmini (HDMI)"
    else
      set_input "$USBC_VALUE"; echo "-> laptop (USB-C)"
    fi
    ;;
  status|get)  status;;
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
