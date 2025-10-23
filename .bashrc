#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Set to superior editing mode
set -o vi

export BASH_SILENCE_DEPRECATION_WARNING=1

export VISUAL=nvim
export EDITOR=nvim

# ~~~~~~~~~~~~~~~ Environment Variables ~~~~~~~~~~~~~~~~~~~~~~~~

# directories
export REPOS="$HOME/Repos"
export GITUSER="marhaasa"
export GHREPOS="$REPOS/github.com/$GITUSER"
export DOTFILES="$GHREPOS/dotfiles"
export SCRIPTS="$DOTFILES/scripts"
export ICLOUD="$HOME/icloud"
export NOTES="$HOME/notes"

# ~~~~~~~~~~~~~~~ Path configuration ~~~~~~~~~~~~~~~~~~~~~~~~
export GOPATH=$HOME/go
#PATH="${PATH:+${PATH}:}"$SCRIPTS":"$HOME"/.local/bin:$HOME/dotnet:/opt/pomo"
PATH="/opt/:$HOME/.local/bin:$HOME/dotnet:${PATH}:/usr/local/bin/:$PATH:$GOPATH/bin"
# ~~~~~~~~~~~~~~~ History ~~~~~~~~~~~~~~~~~~~~~~~~
export HISTFILE=~/.histfile
export HISTSIZE=25000
export SAVEHIST=25000
export HISTCONTROL=ignorespace

# ~~~~~~~~~~~~~~~ Functions ~~~~~~~~~~~~~~~~~~~~~~~~
# Functions are handled by zsh_functions in zsh setup

# ~~~~~~~~~~~~~~~ Aliases ~~~~~~~~~~~~~~~~~~~~~~~~
alias bashrefresh="source ~/.bash_profile"

sintef() {
  "cd /Users/Shared/repos/Sintef/Power BI/"
  "nvim"
}
# cd
alias ..="cd .."
alias repos="cd /Users/Shared/repos"
alias home="cd $HOME"
alias notes="cd $NOTES"
alias icloud="cd \$ICLOUD"
# ls
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -lathr'

# programs
# alias t='tmux'  # No longer using tmux
alias python="python3"
alias v=nvim
# git
alias gp='git pull'
alias gs='git status'
alias lg='lazygit'

# fun
alias fishies=asciiquarium

bind 'set completion-ignore-case on'

# ~~~~~~~~~~~~~~~ Prompt ~~~~~~~~~~~~~~~~~~~~~~~~
eval "$(starship init bash)"

