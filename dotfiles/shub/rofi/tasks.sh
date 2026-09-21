#!/usr/bin/env bash
# A rofi script mode. Entries come from ~/.config/rofi/tasks.d: a .tsv holds "label<TAB>command" lines, a .sh prints the same for a list that lives elsewhere.
set -u

dir="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/tasks.d"

entries() {
  for file in "$dir"/*.tsv "$dir"/*.sh; do
    [ -e "$file" ] || continue
    if [ -x "$file" ]; then "$file"; else cat "$file"; fi
  done | grep -v '^[[:space:]]*$' | sort -u
}

if [ "$#" -eq 0 ]; then
  entries | cut -f 1 | sed 's/$/\x00icon\x1fapplication-x-executable/'
  exit 0
fi

command=$(entries | awk -F '\t' -v label="$1" '$1 == label { print $2; exit }')
[ -n "$command" ] || exit 0

# rofi waits for this script and reads its stdout, so the task must let both go.
setsid -f sh -c "$command" >/dev/null 2>&1 </dev/null
