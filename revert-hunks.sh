#!/usr/bin/env bash
# Reverse-apply only the selected hunks of one file's changes in a commit to the working tree
# (equivalent to SourceTree's "Reverse hunk")
# Usage: revert-hunks.sh <repo-path> <sha> <file>
#   REVERT_HUNKS_DRY_RUN=1         Only run git apply --check
#   REVERT_HUNKS_NO_PAUSE=1        Don't wait for Enter on exit
#   REVERT_HUNKS_SELECTION="1 3"   Use this selection instead of prompting (also accepts "all")

REPO="$1"
SHA="$2"
FILE="$3"
ESC=$(printf '\033')

pause_and_exit() {
  if [ -z "$REVERT_HUNKS_NO_PAUSE" ]; then
    echo
    read -r -p "Press Enter to close..." _
  fi
  exit "$1"
}

if [ -z "$REPO" ] || [ -z "$SHA" ] || [ -z "$FILE" ]; then
  echo "Missing arguments (repo=[$REPO] sha=[$SHA] file=[$FILE])"
  pause_and_exit 1
fi

cd "$REPO" || pause_and_exit 1

if ! git rev-parse --verify --quiet "$SHA^" > /dev/null; then
  echo "Cannot get diff: commit has no parent: $SHA"
  pause_and_exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# For merge commits, diff against the first parent (same as SourceTree / Fork)
git diff --no-color --no-ext-diff "$SHA^" "$SHA" -- "$FILE" > "$WORK_DIR/full.patch"

if [ ! -s "$WORK_DIR/full.patch" ]; then
  echo "No changes to this file in this commit: $FILE"
  pause_and_exit 1
fi

# Split the header and each hunk into separate files, and print the hunk count
HUNK_COUNT=$(awk -v dir="$WORK_DIR" '
  /^@@ / { if (out != "") close(out); n++; out = dir "/hunk_" n ".patch" }
  { if (n == 0) print > (dir "/header.patch"); else print > out }
  END { print n + 0 }
' "$WORK_DIR/full.patch")

if [ "$HUNK_COUNT" -eq 0 ]; then
  echo "No text hunks found (binary file?): $FILE"
  pause_and_exit 1
fi

echo "Commit: $(git log -1 --format='%h %s' "$SHA")"
echo "File: $FILE"
echo

for i in $(seq 1 "$HUNK_COUNT"); do
  HUNK="$WORK_DIR/hunk_$i.patch"
  # Get the new-side line range from "@@ -a,b +c,d @@"
  RANGE=$(head -n 1 "$HUNK" | sed -E 's/^@@ -[0-9]+(,[0-9]+)? \+([0-9]+)(,([0-9]+))? @@.*/\2 \4/')
  START=${RANGE%% *}
  LEN=${RANGE#* }
  [ -z "$LEN" ] && LEN=1
  END=$((START + LEN - 1))
  [ "$LEN" -eq 0 ] && END=$START
  printf '\033[1;36m===== Hunk %d : Lines %d-%d =====\033[0m\n' "$i" "$START" "$END"
  # BSD sed (macOS) doesn't interpret \x1b, so embed a literal ESC character
  tail -n +2 "$HUNK" | sed -E \
    -e "s/^(\+.*)\$/${ESC}[32m\1${ESC}[0m/" \
    -e "s/^(-.*)\$/${ESC}[31m\1${ESC}[0m/"
  echo
done

if [ -n "$REVERT_HUNKS_SELECTION" ]; then
  SELECTION="$REVERT_HUNKS_SELECTION"
  echo "Hunks to revert: $SELECTION"
else
  read -r -p "Hunks to revert (e.g. 1 3, all; empty to cancel): " SELECTION
fi

if [ -z "$SELECTION" ]; then
  echo "Cancelled."
  pause_and_exit 0
fi

if [ "$SELECTION" = "all" ]; then
  SELECTION=$(seq 1 "$HUNK_COUNT")
fi

cp "$WORK_DIR/header.patch" "$WORK_DIR/selected.patch"
SELECTED=""
for i in $(echo "$SELECTION" | tr ',' ' '); do
  if ! [[ "$i" =~ ^[0-9]+$ ]] || [ "$i" -lt 1 ] || [ "$i" -gt "$HUNK_COUNT" ]; then
    echo "Invalid hunk number: $i (valid: 1-$HUNK_COUNT)"
    pause_and_exit 1
  fi
  case " $SELECTED " in
    *" $i "*) continue ;;
  esac
  SELECTED="$SELECTED $i"
done

# Sort by hunk number before concatenating
for i in $(echo "$SELECTED" | tr ' ' '\n' | sort -n); do
  cat "$WORK_DIR/hunk_$i.patch" >> "$WORK_DIR/selected.patch"
done

if [ -n "$REVERT_HUNKS_DRY_RUN" ]; then
  if git apply -R --check "$WORK_DIR/selected.patch"; then
    echo "[DRY RUN] Can be reverted: hunks$SELECTED"
    pause_and_exit 0
  fi
  echo "[DRY RUN] Cannot be applied cleanly (3-way merge will be tried on actual run): hunks$SELECTED"
  pause_and_exit 1
fi

if git apply -R "$WORK_DIR/selected.patch"; then
  echo "Reverted hunks:$SELECTED"
elif git apply -R --3way "$WORK_DIR/selected.patch"; then
  echo "Reverted with 3-way merge (result is staged): hunks$SELECTED"
elif [ -n "$(git diff --name-only --diff-filter=U -- "$FILE")" ]; then
  echo "Conflicts occurred. Resolve them in Fork: hunks$SELECTED"
  pause_and_exit 1
else
  echo "Failed to revert hunks:$SELECTED"
  pause_and_exit 1
fi

pause_and_exit 0
