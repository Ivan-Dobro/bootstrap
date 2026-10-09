# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [ -d "$HOME/.powerlevel10k" ]; then
  source "$HOME/.powerlevel10k/powerlevel10k.zsh-theme"
fi
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export EDITOR="nvim"
export VISUAL="nvim"

alias nv="nvim"
alias ls="eza --tree -L 1 --icons=always --group-directories-first"
alias la="eza --tree -L 1 --icons=always --group-directories-first -la"
alias ldt="eza --icons=always --tree -L 3 --only-dirs"
alias rmd="rm -ri"

mkcd() {
  mkdir -p -- "$1" && builtin cd -- "$1"
}

HISTFILE=$HOME/.zhistory
HISTSIZE=10000
SAVEHIST=10000
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd="z"
fi

if [ -f "$HOME/.fzf.zsh" ]; then
  source "$HOME/.fzf.zsh"
fi

autoload -Uz compinit
compinit
setopt AUTO_MENU
zstyle ':completion:*' menu select

if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# zsh-syntax-highlighting must be sourced after all other shell integrations.
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
