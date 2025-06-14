#!/usr/bin/env bash
# sessions_status.sh: prints tmux sessions styled for status-left
#  session_name 
# Get the current (active) session name
current=$(tmux display-message -p "#S")

# Loop over all session names, one per line
# and print each with appropriate tmux style escapes
while IFS= read -r s; do
  if [ "$s" = "$current" ]; then
    # Active session: pink on purple and bold
    printf "#[fg=#eb6f92,bg=#232136]#[bg=#eb6f92,fg=#232136,bold] %s #[fg=#eb6f92,bg=#232136]#[default] " "$s"
  else
    # Inactive sessions: muted grey
    printf "#[fg=#6e6a86] %s #[default] " "$s"
  fi
done < <(tmux list-sessions -F "#S")
