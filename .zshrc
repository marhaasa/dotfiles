# ~~~~~~~~~~~~~~~ SSH ~~~~~~~~~~~~~~~~~~~~~~~~



# ~~~~~~~~~~~~~~~ Environment Variables ~~~~~~~~~~~~~~~~~~~~~~~~


# Set to superior editing mode

set -o vi

export VISUAL=nvim
export EDITOR=nvim
# export TERM="tmux-256color"  # No longer using tmux

# export BROWSER="firefox"

# Directories

export REPOS="$HOME/Repos"
export GITUSER="marhaasa"
export GHREPOS="$REPOS/github.com/$GITUSER"
export DOTFILES="$GHREPOS/dotfiles"
export SCRIPTS="$DOTFILES/scripts"
export ICLOUD="$HOME/icloud"
export NOTES="$HOME/notes"
export SCRIBE_LANG=no


# ~~~~~~~~~~~~~~~ Path configuration ~~~~~~~~~~~~~~~~~~~~~~~~


setopt extended_glob null_glob

path=(
    /opt/homebrew/opt/python@3.12/bin  # Homebrew Python first
    /opt/homebrew/bin
    /opt/homebrew/opt/dotnet@8/bin
    $HOME/bin
    $HOME/.local/bin
    $HOME/go/bin
    $SCRIPTS
    /opt/homebrew/opt/mssql-tools18/bin
    /Applications/Docker.app/Contents/Resources/bin/
    $HOME/.dotnet/tools
    $HOME/.cargo/bin
    $path  # Original PATH comes last
)

# Remove duplicate entries and non-existent directories
typeset -U path
path=($^path(N-/))

export PATH


# ~~~~~~~~~~~~~~~ History ~~~~~~~~~~~~~~~~~~~~~~~~


HISTFILE=~/.zsh_history
HISTSIZE=120000
SAVEHIST=100000

setopt HIST_IGNORE_SPACE  # Don't save when prefixed with space
setopt HIST_IGNORE_DUPS   # Don't save duplicate lines
setopt SHARE_HISTORY      # Share history between sessions
setopt EXTENDED_HISTORY

# ~~~~~~~~~~~~~~~ Prompt ~~~~~~~~~~~~~~~~~~~~~~~~


PURE_GIT_PULL=0


if [[ "$OSTYPE" == darwin* ]]; then
  fpath+=("$(brew --prefix)/share/zsh/site-functions")
else
  fpath+=($HOME/.zsh/pure)
fi

autoload -U promptinit; promptinit
prompt pure

# Pure prompt configuration
zstyle :prompt:pure:git:stash show yes

autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-magic

# ~~~~~~~~~~~~~~~ Functions ~~~~~~~~~~~~~~~~~~~~~~

update-go-tools() {
  go install github.com/ayn2op/discordo@latest
}

# ~~~~~~~~~~~~~~~ Aliases ~~~~~~~~~~~~~~~~~~~~~~~~

alias ghost="npx ghosttime"

# cd
alias ..="cd .."
alias repos="cd $REPOS"
alias home="cd $HOME"
alias notes="cd $NOTES && nvim -c 'Telescope find_files'"
alias icloud='cd $ICLOUD'
alias dot='cd $DOTFILES'
# ls
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -lathr'

# programs
# alias t='tmux'  # No longer using tmux
alias python="python3"
alias v=nvim
alias ld='lazydocker'
# finds all files recursively and sorts by last modification, ignore hidden files
alias lastmod='find . -type f -not -path "*/\.*" -exec ls -lrt {} +'
alias sync-recordings='$DOTFILES/.zsh_functions/sync-recordings.sh'

# git
alias gp='git pull'
alias gs='git status'
alias lg='lazygit'

# fun
alias fishies=asciiquarium

# history
alias hy="
  fc -ln 0 |
  awk '!a[\$0]++' |
  fzf --tac --multi --header 'Copy history' |
  tr -d '\n' |
  pbcopy
"


# ~~~~~~~~~~~~~~~ Sourcing ~~~~~~~~~~~~~~~~~~~~~~~~
command -v fzf >/dev/null && source <(fzf --zsh)
command -v thefuck >/dev/null && eval $(thefuck --alias)

# ~~~~~~~~~~~~~~~ Functions ~~~~~~~~~~~~~~~~~~~~~~~~


fpath=(~/.zsh_functions $fpath)
autoload -Uz clone

autoload -Uz azclone

autoload -Uz icloud_backup

autoload -Uz icloud_backup_photos

autoload -Uz doc_commands

autoload -Uz sql 

autoload -Uz buildsql

autoload -Uz sqlchanges

autoload -Uz _claude-bootstrap

autoload -Uz claude-dev

autoload -Uz claude-ps

autoload -Uz claude-clean

autoload -Uz claude-attach

autoload -Uz claude-multi

# ~~~~~~~~~~~~~~~ Completion ~~~~~~~~~~~~~~~~~~~~~~~~



if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
fi

autoload -Uz compinit
compinit -u

zstyle ':completion:*' menu select

# added to support case insensitive tab completion for cd
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'



# Example to install completion:
# talosctl completion zsh > ~/.zfunc/_talosctl


# ~~~~~~~~~~~~~~~ Misc ~~~~~~~~~~~~~~~~~~~~~~~~
