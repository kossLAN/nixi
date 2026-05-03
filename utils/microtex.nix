{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  qt6,
  tinyxml-2,
  fontconfig,
}:
stdenv.mkDerivation {
  pname = "microtex";
  version = "unstable-2024-08-05";

  src = fetchFromGitHub {
    owner = "NanoMichael";
    repo = "MicroTeX";
    rev = "0e3707f6dafebb121d98b53c64364d16fefe481d";
    hash = "sha256-U6zqh+VqoLtlE0IwgfwjY9zt8e5/2R3cqf5fWXwoIi0=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  buildInputs = [
    qt6.qtbase
    tinyxml-2
    fontconfig
  ];

  cmakeFlags = [
    "-DQT=ON"
    "-DBUILD_EXAMPLE=OFF"
    "-DHAVE_LOG=OFF"
    "-DGRAPHICS_DEBUG=OFF"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -P libLaTeX* $out/lib/

    cd $src/src
    find . -name "*.h" -exec install -Dm644 {} "$out/include/microtex/{}" \;
    cd -

    mkdir -p $out/share/microtex
    cp -r $src/res $out/share/microtex/

    runHook postInstall
  '';

  dontWrapQtApps = true;

  meta = {
    description = "A dynamic, cross-platform, and embeddable LaTeX rendering library";
    homepage = "https://github.com/NanoMichael/MicroTeX";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
