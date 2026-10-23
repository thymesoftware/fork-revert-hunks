#!/usr/bin/env bash
# Installs the "Revert File Changes" and "Revert Hunks..." custom commands into Fork (Mac)
# Usage:
#   bash install-mac.command               Install / update
#   bash install-mac.command --uninstall   Uninstall
# Environment overrides (for testing): FORK_DIR, INSTALL_DIR

set -e

MODE="install"
[ "$1" = "--uninstall" ] && MODE="uninstall"

HERE="$(cd "$(dirname "$0")" && pwd)"
FORK_DIR="${FORK_DIR:-$HOME/Library/Application Support/com.DanPristupov.Fork}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/fork-scripts}"
CONFIG="$FORK_DIR/custom-commands.json"
SCRIPT_PATH="$INSTALL_DIR/revert-hunks.sh"

finish() {
  echo
  read -r -p "Press Enter to close..." _ || true
  exit "$1"
}

if [ ! -d "$FORK_DIR" ]; then
  echo "Fork settings folder not found: $FORK_DIR"
  echo "Install Fork and launch it once, then run this installer again."
  finish 1
fi

if [ -f "$CONFIG" ]; then
  BACKUP="$CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG" "$BACKUP"
  echo "Backup: $BACKUP"
fi

if [ "$MODE" = "uninstall" ]; then
  rm -f "$SCRIPT_PATH"
  echo "Removed: $SCRIPT_PATH"
else
  if [ ! -f "$HERE/revert-hunks.sh" ]; then
    echo "revert-hunks.sh not found next to this installer: $HERE"
    finish 1
  fi
  mkdir -p "$INSTALL_DIR"
  cp "$HERE/revert-hunks.sh" "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  echo "Installed: $SCRIPT_PATH"
fi

FILE_SCRIPT=$(cat << 'EOF'
cd "${repo:path}" || exit 1
SHA="${sha}"
FILE="${file}"
if [ -z "$SHA" ] || [ -z "$FILE" ]; then echo "Could not get commit or file (sha=[$SHA] file=[$FILE])"; exit 1; fi
if git diff "$SHA^" "$SHA" -- "$FILE" | git apply -R; then
  echo "Reverted: $FILE"
elif git diff "$SHA^" "$SHA" -- "$FILE" | git apply -R --3way; then
  echo "Reverted with 3-way merge (result is staged): $FILE"
else
  echo "Failed to revert: $FILE"; exit 1
fi
EOF
)

# Open an interactive window in Terminal.app (the first time, Fork asks for permission to control Terminal)
HUNK_SCRIPT=$(cat << 'EOF'
cd "${repo:path}" || exit 1
CMD=$(printf '%q ' bash '__SCRIPT__' "$PWD" "${sha}" "${file}")
osascript -e 'on run argv' -e 'tell application "Terminal"' -e 'activate' -e 'do script (item 1 of argv)' -e 'end tell' -e 'end run' "$CMD; exit"
EOF
)
HUNK_SCRIPT="${HUNK_SCRIPT//__SCRIPT__/$SCRIPT_PATH}"

# Read/write JSON with JavaScript for Automation, which ships with macOS
JS_DIR="$(mktemp -d)"
JS_FILE="$JS_DIR/install.js"
trap 'rm -rf "$JS_DIR"' EXIT
cat > "$JS_FILE" << 'EOF'
ObjC.import('Foundation');
function run(argv) {
  const [configPath, mode, fileScript, hunkScript] = argv;
  const names = ['Revert File Changes', 'Revert Hunks…'];
  let entries = [];
  const raw = $.NSString.stringWithContentsOfFileEncodingError(configPath, $.NSUTF8StringEncoding, null);
  if (raw && !raw.isNil() && raw.js.trim().length > 0) {
    entries = JSON.parse(raw.js);
  }
  entries = entries.filter(e => names.indexOf(e.name) < 0);
  if (!entries.some(e => e.version !== undefined)) {
    entries.unshift({ version: 2 });
  }
  if (mode === 'install') {
    entries.push({
      action: { script: fileScript, showOutput: true, type: 'sh', waitForExit: true },
      name: names[0],
      target: 'file'
    });
    entries.push({
      action: { script: hunkScript, showOutput: false, type: 'sh', waitForExit: true },
      name: names[1],
      target: 'file'
    });
  }
  const text = $(JSON.stringify(entries, null, 2) + '\n');
  if (!text.writeToFileAtomicallyEncodingError(configPath, true, $.NSUTF8StringEncoding, null)) {
    throw new Error('Failed to write ' + configPath);
  }
}
EOF

osascript -l JavaScript "$JS_FILE" "$CONFIG" "$MODE" "$FILE_SCRIPT" "$HUNK_SCRIPT"

if [ "$MODE" = "uninstall" ]; then
  echo "Uninstalled. Restart Fork to apply."
else
  echo "Updated: $CONFIG"
  echo "Done. Restart Fork, then right-click a file in a commit to use the commands."
fi
finish 0
