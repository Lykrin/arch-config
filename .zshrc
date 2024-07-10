# .zshrc
# Lazy-load antidote and generate the static load file only when needed
zsh_plugins=${ZDOTDIR:-$HOME}/.zsh_plugins
if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  (
    source /usr/share/zsh-antidote/antidote.zsh
    antidote bundle <${zsh_plugins}.txt >${zsh_plugins}.zsh
  )
fi
source ${zsh_plugins}.zsh

# Env Variables 
export VISUAL='lvim'
export EDITOR='lvim'
export TERMINAL='foot'
export BROWSER='brave'
export HISTORY_IGNORE="(ls|cd|pwd|exit|sudo reboot|history|cd -|cd ..)"
export DMENU='rofi -dmenu'
export IRQBALANCE_ARGS="--allcpus"
export GIT_DISCOVERY_ACROSS_FILESYSTEM=false
export MANPAGER="lvim +Man!"

# Fetch
fastfetch

# Set the file name and size for the command history
HISTFILE=~/.histfile
HISTSIZE=5000
SAVEHIST=5000

# Define some aliases for convenience
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias upgrade='sudo pacman -Syyu'
