{
  pkgs ? import <nixpkgs> { },
  microtex ? pkgs.callPackage ./microtex.nix { },
}:
pkgs.mkShell {
  buildInputs = with pkgs; [
    cmake
    ninja
    pkg-config
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    wayland
    microtex
    tinyxml-2
  ];

  nativeBuildInputs = with pkgs; [
    just
    wayland-scanner
  ];

  shellHook = ''
    export CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)
    # export LD_LIBRARY_PATH=$PWD/debug/lib64
    # export QT_PLUGIN_PATH=$PWD/debug/lib5/plugins:$PWD/debug/lib/qt6/plugins

    # Add Qt-related environment variables.
    # https://discourse.nixos.org/t/qt-development-environment-on-a-flake-system/23707/5
    setQtEnvironment=$(mktemp)
    random=$(openssl rand -base64 20 | sed "s/[^a-zA-Z0-9]//g")
    makeShellWrapper "$(type -p sh)" "$setQtEnvironment" "''${qtWrapperArgs[@]}" --argv0 "$random"
    sed "/$random/d" -i "$setQtEnvironment"
    source "$setQtEnvironment"

    # qmlls does not account for the import path and bases its search off qtbase's path.
    # The actual imports come from qtdeclarative. This directs qmlls to the correct imports.
    export QMLLS_BUILD_DIRS=$(pwd)/build:$QML2_IMPORT_PATH
  '';
}
