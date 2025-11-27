#!/usr/bin/env bash
# rsync-diff.sh
# Wrapper for rsync that shows diffs (unified) for files before performing the sync.
# Usage: ./rsync-diff.sh [rsync options] SRC DEST
# Example: ./rsync-diff.sh -az --delete /local/dir/ user@remote:/remote/dir/

set -euo pipefail
IFS=$'\n\t'

# Helper: print usage
usage() {
  cat <<EOF
Usage: $0 [rsync-options...] SRC DEST
Example: $0 -az --delete /local/dir/ user@host:/remote/dir/
Notes:
 - The last two arguments are treated as SRC and DEST. All preceding args are passed to rsync.
 - Works with local and remote (user@host:/path) sources or destinations.
EOF
  exit 1
}

if [ "$#" -lt 2 ]; then
  usage
fi

# Extract src & dest (last two args); others are rsync options
args=("$@")
arg_count=$#
src="${args[$((arg_count-2))]}"
dest="${args[$((arg_count-1))]}"
# Collect rsync options (all except last two)
rsync_opts=("${args[@]:0:$((arg_count-2))}")

# Temporary working dir
tmpdir="$(mktemp -d -t rsync-diff.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

# Function to check if a path is remote (contains first colon before any slash)
is_remote() {
  local p="$1"
  # If contains ":" before first "/" -> remote like user@host:/path
  if [[ "$p" =~ ^[^/]+:[/]{0,1}.*$ ]]; then
    return 0
  else
    return 1
  fi
}

# Fetch a single file from local or remote into a destination path
# fetch_file <side_path> <file_relative_path> <output_file>
fetch_file() {
  local side="$1"      # SRC or DEST base
  local rel="$2"       # relative file path (may contain spaces)
  local out="$3"       # local output file path
  mkdir -p "$(dirname "$out")"
  if is_remote "$side"; then
    # split remote into host and path
    # the first ":" splits host and path
    local host="${side%%:*}"
    local basepath="${side#*:}"
    # remote file path is basepath + "/" + rel (handle trailing slash)
    # if basepath ends with /, avoid duplicating slashes
    if [[ "$basepath" == */ ]]; then
      remote_path="${basepath}${rel}"
    else
      remote_path="${basepath%/}/${rel}"
    fi
    # use ssh to cat the file (preserves binary? we write raw)
    # if file doesn't exist, the ssh will fail; we handle non-zero return
    if ssh "$host" "test -f \"${remote_path}\"" >/dev/null 2>&1; then
      ssh "$host" "cat \"${remote_path}\"" >"$out" 2>/dev/null || true
    else
      # file doesn't exist on remote; leave empty but mark
      : >"$out"
      return 2
    fi
  else
    # local side
    # build absolute path: side may be a directory or path containing filename itself
    if [[ "$side" == */ ]] || [[ -d "$side" ]]; then
      local fullpath="${side%/}/${rel}"
    else
      # if side is a file-like path, treat it as dir if necessary
      local fullpath="${side%/}/${rel}"
    fi
    if [ -f "$fullpath" ]; then
      cat "$fullpath" >"$out" || true
    else
      : >"$out"
      return 2
    fi
  fi
  return 0
}

# Run rsync dry-run and capture itemized output
# We use --itemize-changes (%i is 11 chars) so we can reliably split flags and filename
echo "Running rsync dry-run to detect changes..."
dryrun_output_file="$tmpdir/rsync-dryrun.txt"
# Build command
cmd=(rsync -n --itemize-changes --out-format='%i %n' "${rsync_opts[@]}" "$src" "$dest")
# Execute and capture both stdout and stderr (rsync prints deletions as "deleting ...")
"${cmd[@]}" >"$dryrun_output_file" 2>&1 || true

if [ ! -s "$dryrun_output_file" ]; then
  echo "No changes detected by rsync (dry-run). Nothing to do."
  exit 0
fi

echo "Parsing changes..."
files_to_process=()
deletions=()

# parse dry-run output
while IFS= read -r line; do
  # skip empty
  [[ -z "$line" ]] && continue
  if [[ "$line" == deleting\ * ]]; then
    # deletion line: "deleting path/with spaces"
    fname="${line#deleting }"
    deletions+=("$fname")
    files_to_process+=("$fname|DELETED")
  else
    # itemize format: first 11 chars = flags, then space, then filename
    flags="${line:0:11}"
    fname="${line:12}"    # preserves spaces
    # we care about files (starting with 'f' in flags) and symlinks etc - show diffs for regular files
    # If flags contain '>' or '*' etc it's a transfer/change/new
    # We'll include everything that isn't just a metadata-only change?
    files_to_process+=("$fname|$flags")
  fi
done <"$dryrun_output_file"

if [ "${#files_to_process[@]}" -eq 0 ]; then
  echo "No files to process after parsing. Exiting."
  exit 0
fi

echo
echo "Found ${#files_to_process[@]} affected path(s). Showing diffs (if applicable)."
echo "-----------------------------------------------------------------------"
sleep 0.2

# Process each file: fetch src & dest versions and show unified diff
count=0
for entry in "${files_to_process[@]}"; do
  count=$((count+1))
  # split into fname and flags
  fname="${entry%%|*}"
  flags="${entry#*|}"
  echo
  echo "[$count/${#files_to_process[@]}] ${fname}"
  echo "Change flags: ${flags}"
  # Create temp files
  src_tmp="$tmpdir/src--$(printf '%03d' "$count").bin"
  dst_tmp="$tmpdir/dst--$(printf '%03d' "$count").bin"

  # Fetch source file
  fetch_file "$src" "$fname" "$src_tmp"
  src_status=$?
  # Fetch dest file
  fetch_file "$dest" "$fname" "$dst_tmp"
  dst_status=$?

  # Determine what to show:
  # If both non-empty or both exist, show diff -u
  # If src exists and dest missing -> "new file" show full src
  # If dest exists and src missing -> "deletion" show full dest (and mark deletion)
  # Use diff -u for text files; for binary, use file check and show "binary differ" message

  # Helper to detect binary (simple heuristic: use grep to find NUL)
  is_binary_file() {
    local f="$1"
    if [ ! -s "$f" ]; then
      return 1  # treat empty as not binary (but non-existent handled above)
    fi
    if grep -qUaP "\x00" "$f" 2>/dev/null; then
      return 0
    else
      return 1
    fi
  }

  if [ "$src_status" -eq 2 ] && [ "$dst_status" -eq 2 ]; then
    echo "  -> Neither side has a regular file (maybe directories or metadata change). Skipping diff."
    continue
  fi

  if [ "$src_status" -eq 0 ] && [ "$dst_status" -eq 0 ]; then
    # both exist: diff
    if is_binary_file "$src_tmp" || is_binary_file "$dst_tmp"; then
      echo "  -> Binary file changed. (skipping textual diff)"
      # Show size summary
      src_size=$(stat -c%s "$src_tmp" 2>/dev/null || echo 0)
      dst_size=$(stat -c%s "$dst_tmp" 2>/dev/null || echo 0)
      echo "     src size: $src_size bytes, dst size: $dst_size bytes"
    else
      echo "---- unified diff ----"
      diff -u --label "SRC: $src/$fname" --label "DST: $dest/$fname" "$dst_tmp" "$src_tmp" || true
      echo "---- end diff ----"
    fi
  elif [ "$src_status" -eq 0 ] && [ "$dst_status" -eq 2 ]; then
    echo "  -> New file (will be created on destination). Showing content:"
    if is_binary_file "$src_tmp"; then
      echo "     Binary file (src). Size: $(stat -c%s "$src_tmp") bytes"
    else
      echo "---- file content (src) ----"
      sed -n '1,200p' "$src_tmp"
      if [ $(wc -l <"$src_tmp") -gt 200 ]; then
        echo "    ... (truncated)"
      fi
      echo "---- end content ----"
    fi
  elif [ "$src_status" -eq 2 ] && [ "$dst_status" -eq 0 ]; then
    echo "  -> File will be deleted from destination. Showing current destination content:"
    if is_binary_file "$dst_tmp"; then
      echo "     Binary file (dst). Size: $(stat -c%s "$dst_tmp") bytes"
    else
      echo "---- file content (dst) ----"
      sed -n '1,200p' "$dst_tmp"
      if [ $(wc -l <"$dst_tmp") -gt 200 ]; then
        echo "    ... (truncated)"
      fi
      echo "---- end content ----"
    fi
  else
    echo "  -> Unknown status for file; skipping."
  fi
done

echo
echo "Summary: ${#files_to_process[@]} path(s) shown."
echo
# Ask user to proceed
read -r -p "Proceed with rsync (run actual sync) ? [y/N] " answer
answer=${answer:-N}
if [[ "$answer" =~ ^[Yy]$ ]]; then
  echo "Running rsync for real..."
  # Build actual rsync command (no -n)
  real_cmd=(rsync "${rsync_opts[@]}" "$src" "$dest")
  echo "+ ${real_cmd[*]}"
  "${real_cmd[@]}"
  echo "rsync finished."
else
  echo "Aborted by user. No changes made."
fi

exit 0