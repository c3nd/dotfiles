#!/usr/bin/env fish
# Cassiopeia fish config: aliases + faster-whisper X11 dictation helpers

function faster-whisper-toggle
  set STATE_DIR (test -n "$XDG_STATE_HOME"; and echo $XDG_STATE_HOME; or echo "$HOME/.local/state")/faster-whisper
  set SCRIPT "$HOME/dotfiles/config/faster-whisper-toggle.sh"
  if test -f "$STATE_DIR/.recording"
    $SCRIPT stop
  else
    $SCRIPT start
  end
end

function faster-whisper-postprocess
  "$HOME/dotfiles/config/faster-whisper-toggle.sh" postprocess
end

function faster-whisper-cancel
  "$HOME/dotfiles/config/faster-whisper-toggle.sh" cancel
end

alias btw "echo i use nixos, btw"
alias nsw "nh os switch"
alias nhm "nh home switch"
alias nbo "nh os boot"
alias nrb "nh os rollback"
alias nif "nh os info"
alias ndry "nh os switch --dry"
alias ncl "nh clean all -k 3"
alias plspush "cd ~/dotfiles; and git add -A; and git commit -m 'autocommit'; and git push; and cd ~"
