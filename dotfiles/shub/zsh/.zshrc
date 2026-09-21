[ -r "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ] && source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
[ -e "$HOME/vulkan/1.4.321.1/setup-env.sh" ] && source "$HOME/vulkan/1.4.321.1/setup-env.sh"

command -v fd >/dev/null 2>&1 && export FZF_DEFAULT_COMMAND='fd --type f --hidden --no-ignore'
export FZF_DEFAULT_OPTS="--bind 'ctrl-j:down,ctrl-k:up' --no-mouse"

# overrides EDITOR=nano from /etc/set-environment
export EDITOR="nvim"
export VISUAL="$EDITOR"

# read from disk, not Nix: home.sessionVariables lands in the world-readable store
[ -r "$HOME/.config/deepseek/api_key" ] && export DEEPSEEK_API_KEY="$(<"$HOME/.config/deepseek/api_key")"

# Zinit and its plugins, cloned on first start
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ -d "$ZINIT_HOME" ] || git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo

autoload -Uz compinit && compinit -u
zinit cdreplay -q

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search edit-command-line
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
zle -N edit-command-line

# Vi mode: no ESC delay, backspace keeps deleting after a trip through normal mode, 'vv' edits the line in nvim.
bindkey -v
export KEYTIMEOUT=1
bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey -M vicmd 'vv' edit-command-line
bindkey '^p' up-line-or-beginning-search
bindkey '^n' down-line-or-beginning-search
bindkey '^y' autosuggest-accept
bindkey '^u' forward-word

HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_ignore_dups hist_find_no_dups

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

alias ls="ls --color"
alias c="clear"
alias ldev="nix develop --command $SHELL -il"
alias gdev="nix develop $HOME/develop --command $SHELL -il"
alias lnvim="nix develop --command $SHELL -il -c 'nvim .'"
alias gnvim="nix develop $HOME/develop --command $SHELL -il -c 'nvim .'"
alias git-rename-branch="$HOME/develop/scripts/git-rename-branch.sh"
alias reload="source ${ZDOTDIR:-$HOME}/.zshrc"

eval "$(fzf --zsh)"
# Greet before the tool inits; zoxide wants its init to stay last. (Off the launcher: `-e zsh -c` broke the terminfo-over-ssh integration.)
[[ -z $TMUX && $SHLVL -eq 1 ]] && fastfetch

eval "$(zoxide init --cmd cd zsh)"

command_not_found_handler() {
  if ! command -v nix-locate >/dev/null 2>&1; then
    echo "nix-locate is missing; it comes with the system config (nix-index-database)."
    return 127
  fi
  local results=$(nix-locate --whole-name "/bin/$1" 2>/dev/null | head -n 10)
  if [ -z "$results" ]; then
    echo "Command '$1' not found in nixpkgs index."
  else
    echo "Found possible matches:"
    echo "$results"
  fi
  return 127
}

eval "$(starship init zsh)"
