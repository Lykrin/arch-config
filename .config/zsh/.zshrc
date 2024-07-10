# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Antidote plugin manager setup
zsh_plugins=${ZDOTDIR:-$HOME}/.zsh_plugins
if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  (
    source /usr/share/zsh-antidote/antidote.zsh
    antidote bundle <${zsh_plugins}.txt >${zsh_plugins}.zsh
  )
fi
source ${zsh_plugins}.zsh

# History configuration
HISTFILE=~/.histfile
HISTSIZE=5000
SAVEHIST=5000
setopt HIST_IGNORE_ALL_DUPS  # Don't record duplicates in history
setopt HIST_SAVE_NO_DUPS     # Don't write duplicate entries in the history file

# Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias upgrade='sudo pacman -Syyu'

# Load Powerlevel10k theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Environment variables
export VISUAL='nvim'
export EDITOR='nvim'
export TERMINAL='foot'
export BROWSER='brave'
export HISTORY_IGNORE="(ls|cd|pwd|exit|sudo reboot|history|cd -|cd ..)"
export DMENU='fuzzel -dmenu'
export IRQBALANCE_ARGS="--allcpus"
export GIT_DISCOVERY_ACROSS_FILESYSTEM=false
export MANPAGER="nvim +Man!"

# Completion system initialization
autoload -Uz compinit
compinit

# Run fastfetch
fastfetch