{ config, lib, pkgs, inputs, ... }:

with lib;

let

  cfg = config.programs.cake-wallet;


  cakeWallet =
    pkgs.stdenv.mkDerivation {

      pname = "cake-wallet";
      version = "latest";


      src = inputs.cake-wallet-src;


      nativeBuildInputs = [
        pkgs.autoPatchelfHook
        pkgs.makeWrapper
      ];


      buildInputs = [

        # Flutter / GTK
        pkgs.gtk3
        pkgs.glib
        pkgs.pango
        pkgs.cairo
        pkgs.gdk-pixbuf

        # C/C++ runtime
        pkgs.gcc.cc.lib
        pkgs.stdenv.cc.cc.lib

        # Crypto / USB
        pkgs.libgcrypt
        pkgs.libgpg-error
        pkgs.libusb1

        # Compression
        pkgs.xz
        pkgs.lz4
        pkgs.zlib

        # System libs
        pkgs.util-linux
        pkgs.libuuid

        # Secrets
        pkgs.libsecret

        # Network
        pkgs.nss
        pkgs.openssl

        # Audio
        pkgs.alsa-lib
        pkgs.pulseaudio

        # X11
        pkgs.libx11
        pkgs.libxcb
        pkgs.libxrandr
        pkgs.libxi
        pkgs.libxinerama
        pkgs.libxcursor

        # Fonts
        pkgs.fontconfig
        pkgs.freetype
      ];


      unpackPhase = ''
        runHook preUnpack

        mkdir source
        cp -r $src/* source/

        cd source

        runHook postUnpack
      '';



      preFixup = ''
        autoPatchelfIgnoreMissingDeps=1
      '';



      installPhase = ''
        runHook preInstall


        mkdir -p $out/bin
        mkdir -p $out/share/applications


        cp -r . $out/


        chmod +x $out/cake_wallet



        makeWrapper \
          $out/cake_wallet \
          $out/bin/cake-wallet \
          --prefix LD_LIBRARY_PATH : ${
            pkgs.lib.makeLibraryPath [

              pkgs.gtk3
              pkgs.glib
              pkgs.pango
              pkgs.cairo
              pkgs.gdk-pixbuf

              pkgs.libsecret

              pkgs.gcc.cc.lib

              pkgs.libusb1
              pkgs.libgcrypt
              pkgs.libgpg-error

              pkgs.xz
              pkgs.lz4

              pkgs.libx11
              pkgs.libxcb
              pkgs.libxrandr
              pkgs.libxi
              pkgs.libxinerama
              pkgs.libxcursor

              pkgs.alsa-lib
              pkgs.pulseaudio

              pkgs.fontconfig
              pkgs.freetype

            ]
          };



        cat > $out/share/applications/cake-wallet.desktop <<EOF

[Desktop Entry]
Name=Cake Wallet
Comment=Privacy cryptocurrency wallet
Exec=cake-wallet
Terminal=false
Type=Application
Categories=Finance;

EOF


        runHook postInstall
      '';

    };


in {

  options.programs.cake-wallet = {

    enable =
      mkEnableOption "Cake Wallet";


    hardwareWallets =
      mkOption {
        type = types.bool;
        default = true;
      };

  };



  config = mkIf cfg.enable {

    environment.systemPackages = [
      cakeWallet
    ];


    services.udev.packages =
      mkIf cfg.hardwareWallets [
        pkgs.trezor-udev-rules
      ];

  };

}
