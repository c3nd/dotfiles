# System-wide package list (imported by configuration.nix).
#
# Packages are grouped by category for legibility. Add new packages under the
# most relevant group. `with pkgs;` lets us reference packages by bare name.
{ pkgs, ... }:
with pkgs;
[
  ############################################################################
  # Editors & IDEs
  ############################################################################
  vim
  kdePackages.kate

  ############################################################################
  # Version control & development
  ############################################################################
  git
  gcc
  gnumake
  pkg-config
  nil # Nix LSP
  uv # Python package/venv manager
  python314

  ############################################################################
  # Office & documents
  ############################################################################
  libreoffice-qt6-fresh
  hunspell
  hunspellDicts.uk_UA

  ############################################################################
  # Terminal & system utilities
  ############################################################################
  kitty
  foot
  starship
  eza
  btop
  jq
  lshw
  nnn
  lm_sensors
  trash-cli
  gnome-keyring
  cliphist
  wl-screenrec
  wf-recorder
  wl-clipboard
  hyprpicker

  ############################################################################
  # Theming & desktop helpers
  ############################################################################
  kdePackages.qt6ct
  kdePackages.qtsvg
  kdePackages.dolphin
  kdePackages.dolphin-plugins
  kdePackages.kio-fuse
  kdePackages.kio-extras
  kdePackages.plasma-workspace

  ############################################################################
  # Media & graphics
  ############################################################################
  krita
  xnviewmp
  # kopuz (music player) is installed via the flake — see flake.nix.
  pavucontrol
  fastfetch
  motrix-next
  equibop

  ############################################################################
  # Gaming
  ############################################################################
  prismlauncher

  ############################################################################
  # Vulkan / graphics libraries
  ############################################################################
  vulkan-loader
  vulkan-tools

  ############################################################################
  # Mobile / device tooling
  ############################################################################
  android-file-transfer
  scrcpy
  signal-desktop

  ############################################################################
  # Networking & VPN
  ############################################################################
  cloudflare-warp

  ############################################################################
  # Compression
  ############################################################################
  p7zip
  zlib

  ############################################################################
  # Misc / runtime libraries & tools
  ############################################################################
  upower
  libinput
  llmfit
  app2unit
  openssl_3
  leveldb
]
