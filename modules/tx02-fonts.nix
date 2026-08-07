{ lib, stdenv }:

stdenv.mkDerivation {
  pname = "tx02-fonts";
  version = "1.0.0";

  src = ./themes/space/fonts/tx02;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype/tx02
    cp -v *.otf $out/share/fonts/truetype/tx02/
    runHook postInstall
  '';

  meta = with lib; {
    description = "TX-02 font family for Cassiopeia";
    license = licenses.unfree;
    platforms = platforms.all;
  };
}
