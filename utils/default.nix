{
  callPackage,
  stdenv,
  cmake,
  pkg-config,
  qt6,
  wayland,
  wayland-scanner,
  wlr-protocols,
  microtex ? callPackage ./microtex.nix { },
  tinyxml-2,
}:
stdenv.mkDerivation {
  name = "utils-plugin";
  src = ./.;

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    wayland
    microtex
    tinyxml-2
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
    wayland-scanner
  ];

  cmakeFlags = [
    "-DMICROTEX_RES_DIR=${microtex}/share/microtex/res"
    "-DWLR_PROTOCOLS_DIR=${wlr-protocols}/share/wlr-protocols"
  ];

  dontWrapQtApps = true;
}
