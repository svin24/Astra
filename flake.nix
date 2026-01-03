{
  description = "Astra";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/f8a04e05dcaac5be36f2cb6c70a55d4538146741";
    flake-utils.url = "github:numtide/flake-utils";
    kdsingleapplication = {
      url = "github:KDAB/kdsingleapplication/3186a158f8e6565e89f5983b4028c892737844ff";
      flake = false;
    };
    libcotp = {
      url = "github:paolostivanin/libcotp/7725397cbd9c268fd913dfa91f78f90673bf85b2";
      flake = false;
    };
    libphysis = {
      url = "github:redstrate/libphysis/ffe4ed11c5ba132a12fd9b660eb48268e7894419";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      kdsingleapplication,
      libcotp,
      libphysis,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        kdePackages = pkgs.kdePackages;
        miscelSrc = pkgs.fetchFromGitHub {
          owner = "redstrate";
          repo = "miscel";
          rev = "4d241ffc0c25867e2d896a148e0d48db9d7e0113";
          hash = "sha256-vZTvIrddy/DbYR+SNmX0uZ8vwoU39N6g00LnrvOo31o=";
        };
        physisSrc = pkgs.fetchFromGitHub {
          owner = "redstrate";
          repo = "physis";
          rev = "bf8d2b56bc48cd3d2d778c9792a1c74e95438bd7";
          hash = "sha256-plCw60CSW6LSipO4KcM2XWPL9y4IpbqGe3dZ+m9brlw=";
        };
        libphysisVendor = pkgs.rustPlatform.fetchCargoVendor {
          src = libphysis;
          cargoLock = "${libphysis}/Cargo.lock";
          hash = "sha256-TGL0H9yVCA5ue/T1uOvhIrXWotCAb2Q8oZ/iiaiG5IA=";
        };
      in
      {
        packages = rec {
          astra = pkgs.stdenv.mkDerivation {
            pname = "astra";
            version = "0.9.0";
            src = pkgs.lib.cleanSourceWith {
              src = self;
              filter =
                path: type:
                let
                  base = builtins.baseNameOf path;
                in
                base != ".git" && base != ".flatpak-builder" && base != "build";
            };

            nativeBuildInputs = [
              pkgs.cmake
              pkgs.ninja
              pkgs.pkg-config
              kdePackages.extra-cmake-modules
              kdePackages.wrapQtAppsHook
            ];

            postPatch = ''
              ln -s ${kdsingleapplication} external/kdsingleapplication
              ln -s ${libcotp} external/libcotp
              cp -R ${libphysis} external/libphysis
              chmod -R u+w external/libphysis
            '';

            preConfigure = ''
              export CARGO_HOME="$TMPDIR/cargo"
              mkdir -p "$CARGO_HOME"
              cat > "$CARGO_HOME/config.toml" <<EOF
              [source.crates-io]
              replace-with = "vendored-sources"

              [source.vendored-sources]
              directory = "${libphysisVendor}"

              [patch."https://github.com/redstrate/miscel"]
              miscel = { path = "${miscelSrc}" }

              [patch."https://github.com/redstrate/physis"]
              physis = { path = "${physisSrc}" }
              EOF
            '';

            buildInputs = [
              pkgs.libcotp
              pkgs.libgcrypt
              kdePackages.qtbase
              kdePackages.qtdeclarative
              kdePackages.qtwebview
              kdePackages.kirigami
              kdePackages.kirigami-addons
              kdePackages.ki18n
              kdePackages.kconfig
              kdePackages.kcoreaddons
              kdePackages.karchive
              pkgs.corrosion
              pkgs.rustc
              pkgs.cargo
              pkgs.unshield
              kdePackages.qtkeychain
              kdePackages.qcoro
              kdePackages.kdeclarative
            ];
          };

          default = astra;
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.astra}/bin/astra";
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.astra ];
          packages = [
            pkgs.cmake
            pkgs.ninja
            pkgs.pkg-config
          ];
        };
      }
    );
}
