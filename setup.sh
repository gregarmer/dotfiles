#!/bin/bash

# This is safe to run multiple times and will prompt you about anything unclear

answer_is_yes() {
  [[ "$REPLY" =~ ^[Yy]$ ]] && return 0 || return 1
}

ask() {
  print_question "$1"
  read -r
}

ask_for_confirmation() {
  print_question "$1 (y/n) "
  read -r -n 1
  printf "\\n"
}

ask_for_sudo() {
  # Prompt for sudo upfront
  sudo -v

  # Update existing `sudo` time stamp until this script has finished
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done &> /dev/null &
}

cmd_exists() {
  [ -x "$(command -v "$1")" ] && printf 0 || printf 1
}

execute() {
  $1 &> /dev/null
  print_result $? "${2:-$1}"
}

get_answer() {
  printf "%s" "$REPLY"
}

get_os() {
  local -r OS_NAME="$(uname -s)"
  local os=""

  if [ "$OS_NAME" == "Darwin" ]; then
    os="osx"
  elif [ "$OS_NAME" == "Linux" ] && [ -e "/etc/lsb-release" ]; then
    os="ubuntu"
  fi

  printf "%s" "$os"
}

is_git_repository() {
  [ "$(git rev-parse &>/dev/null; print $?)" -eq 0 ] && return 0 || return 1
}

mkd() {
  if [ -n "$1" ]; then
    if [ -e "$1" ]; then
      if [ ! -d "$1" ]; then
        print_error "$1 - a file with the same name already exists!"
      else
        print_success "$1"
      fi
    else
      execute "mkdir -p $1" "$1"
    fi
  fi
}

print_error() {
  printf "\\e[0;31m  [✖] %s %s\\e[0m\\n" "$1" "$2"
}

print_info() {
  printf "\\n\\e[0;35m %s\\e[0m\\n\\n" "$1"
}

print_question() {
  printf "\\e[0;33m  [?] %s\\e[0m" "$1"
}

print_result() {
  if [ "$1" -eq 0 ]; then
    print_success "$2"
  else
    print_error "$2"
  fi
  [ "$3" == "true" ] && [ "$1" -ne 0 ] && exit
}

print_success() {
  printf "\\e[0;32m  [✔] %s\\e[0m\\n" "$1"
}

while true; do
  read -r -p "Warning: this will overwrite your current dotfiles. Continue? [y/n] " yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) exit;;
    * ) echo "Please answer yes or no.";;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" || exit 1; pwd -P)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
DOTFILES_BACKUP=~/dotfiles-backup-$(date +"%Y-%m-%d-%H:%M:%S")

# Get current dir (so run this script from anywhere)
export DOTFILES_DIR
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create $DOTFILES_BACKUP in homedir
echo -n "Creating $DOTFILES_BACKUP for backup of any existing dotfiles in ~ ... "
mkdir -p "$DOTFILES_BACKUP"
echo "done"

# Change to the dotfiles directory
echo -n "Changing to the $DOTFILES_DIR directory ... "
cd "$DOTFILES_DIR" || exit 1
echo "done"

#
# Actual symlink stuff
#

declare -a FILES_TO_SYMLINK=(
  'git/gitattributes'
  'git/gitconfig'
  'git/gitignore'

  'zsh/zshrc'
)

print_info "Backing up existing dotfiles ... "
for i in "${FILES_TO_SYMLINK[@]}"; do
  f=~/.${i##*/}
  if [ -f "$f" ]; then
    execute "mv $f $DOTFILES_BACKUP" "$f → $DOTFILES_BACKUP"
  fi
done

main() {
  local i=''
  local sourceFile=''
  local targetFile=''

  print_info "Symlinking new files into place ... "
  for i in "${FILES_TO_SYMLINK[@]}"; do
    sourceFile="$(pwd)/$i"
    targetFile="$HOME/.$(printf "%s" "$i" | sed "s/.*\\/\\(.*\\)/\\1/g")"

    if [ ! -e "$targetFile" ]; then
      execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
    elif [ "$(readlink "$targetFile")" == "$sourceFile" ]; then
      print_success "$targetFile → $sourceFile"
    else
      ask_for_confirmation "'$targetFile' already exists, do you want to overwrite it?"
      if answer_is_yes; then
        rm -rf "$targetFile"
        execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
      else
        print_error "$targetFile → $sourceFile"
      fi
    fi
  done

  unset FILES_TO_SYMLINK
}

install_zsh () {
  print_info "Checking if we need to install zsh ..."

  # Test to see if zshell is installed.  If it is:
  if [ -f /bin/zsh ] || [ -f /usr/bin/zsh ]; then
    print_success "zsh is already installed"

    # Set the default shell to zsh if it isn't currently set to zsh
    if [ "$(getent passwd "$USER" | awk -F: '{print $NF}')" == "$(which zsh)" ]; then
      print_success "Shell is already set to zsh"
    else
      print_error "Your defualt shell is not zsh, please run this: chsh -s $(which zsh)"
    fi
  else
    # If zsh isn't installed, get the platform of the current machine
    platform=$(uname);
    # If the platform is Linux, try an apt-get to install zsh and then recurse
    if [[ $platform == 'Linux' ]]; then
      if [[ -f /etc/redhat-release ]]; then
        sudo yum install zsh
        install_zsh
      elif [[ -f /etc/debian_version ]]; then
        sudo apt-get install zsh
        install_zsh
      elif [ -f /etc/arch-release ]; then
        sudo pacman -Sy zsh
	install_zsh
      fi
    # If the platform is OS X, tell the user to install zsh :)
    elif [[ $platform == 'Darwin' ]]; then
      echo "We'll install zsh, then re-run this script!"
      brew install zsh
      exit
    fi
  fi
}

main
install_zsh

## Copy over Atom configs
##cp -r atom/packages.list $HOME/.atom
#
## Install community packages
##apm list --installed --bare - get a list of installed packages
##apm install --packages-file $HOME/.atom/packages.list

# OS Specifics
platform=$(uname)
if [ "$platform" == 'Linux' ]; then
  if [ -f /etc/redhat-release ]; then
    print_info "Setting up specifics for RedHat/CentOS ..."
  elif [ -f /etc/debian_version ]; then
    print_info "Setting up specifics for Debian ..."
  elif [ -f /etc/arch-release ]; then
    print_info "Setting up specifics for ArchLinux ..."
  fi
elif [ "$platform" == 'Darwin' ]; then
  print_info "Setting up specifics for OSX ..."

  defaults write com.apple.terminal StringEncodings -array 4
  print_success "Only use UTF-8 in Terminal.app"

  defaults write com.googlecode.iterm2 PromptOnQuit -bool false
  print_success "Don’t display the annoying prompt when quitting iTerm"

  # . "$DOTFILES_DIR/install/brew.sh"
  # . "$DOTFILES_DIR/install/npm.sh"

  # if [ "$(uname)" == "Darwin" ]; then
      # . "$DOTFILES_DIR/install/brew-cask.sh"
  # fi
fi

# Reload zsh settings
#source ~/.zshrc
