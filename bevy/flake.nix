{
  inputs = {
    fenix.url = "github:nix-community/fenix";
    naersk.url = "github:nix-community/naersk/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";

    nixpkgs-mozilla = {
      url = "github:mozilla/nixpkgs-mozilla";
      flake = false;
    };
  };

  outputs = {
    self,
    fenix,
    nixpkgs,
    utils,
    naersk,
    nixpkgs-mozilla,
  }:
    utils.lib.eachDefaultSystem (system: let
      # Change this to the Rust project
      package_name = "bevy_game";
      package_version = "0.0.1";

      pkgs = (import nixpkgs) {
        inherit system;

        overlays = [
          (import nixpkgs-mozilla)
        ];
      };

      windowsToolchain = with fenix.packages.${system};
        combine [
          minimal.rustc
          minimal.cargo
          targets.x86_64-pc-windows-gnu.latest.rust-std
        ];

      wasmToolchain = with fenix.packages.${system};
        combine [
          minimal.rustc
          minimal.cargo
          targets.wasm32-unknown-unknown.latest.rust-std
        ];

      windowsNaersk = pkgs.callPackage naersk {
        cargo = windowsToolchain;
        rustc = windowsToolchain;
      };

      wasmNaersk = pkgs.callPackage naersk {
        cargo = wasmToolchain;
        rustc = wasmToolchain;
      };

      toolchain =
        (pkgs.rustChannelOf {
          rustToolchain = ./rust-toolchain.toml;
          sha256 = "sha256-Lhepl2K16hDOfGs22fr4kywRkNZ5yFCODlxvhlK9e/E=";
        })
        .rust;

      naersk-lib = pkgs.callPackage naersk {
        cargo = toolchain;
        rustc = toolchain;
      };

      neededDeps = with pkgs; [
        udev
        alsaLib
        xorg.libX11
        xorg.libXcursor
        xorg.libXi
        xorg.libXrandr
        vulkan-loader
        clang
        pkg-config
        mold
      ];

      neededNativeDeps = [];

      libPath = with pkgs; lib.makeLibraryPath neededDeps;
    in {
      defaultPackage = naersk-lib.buildPackage rec {
        src = ./.;
        pname = package_name;
        version = package_version;

        cargoBuildOptions = x:
          x
          ++ [
            "--no-default-features"
          ];

        buildInputs = neededDeps;

        nativeBuildInputs =
          [
            pkgs.makeWrapper
          ]
          ++ neededNativeDeps;

        postInstall = ''
          mkdir -p $out/bin
          cp -r $src/assets $out/bin
          wrapProgram "$out/bin/${pname}" --prefix LD_LIBRARY_PATH : "${libPath}"
        '';
      };

      packages.x86_64-pc-windows-gnu = windowsNaersk.buildPackage {
        src = ./.;
        pname = package_name;
        version = package_version;
        strictDeps = true;

        cargoBuildOptions = x:
          x
          ++ [
            "--no-default-features"
          ];

        depsBuildBuild = with pkgs; [
          pkgsCross.mingwW64.stdenv.cc
          pkgsCross.mingwW64.windows.pthreads
        ];

        buildInputs = neededDeps;

        nativeBuildInputs =
          [
          ]
          ++ neededNativeDeps;

        postInstall = ''
          mkdir -p $out/bin
          cp -r $src/assets $out/bin
        '';

        CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
      };

      wasm32-unknown-unknown = wasmNaersk.buildPackage {
        src = ./.;
        pname = package_name;
        version = package_version;
        strictDeps = true;

        cargoBuildOptions = x:
          x
          ++ [
            "--no-default-features"
          ];

        buildInputs = neededDeps;

        nativeBuildInputs =
          [
          ]
          ++ neededNativeDeps;

        postInstall = ''
          mkdir -p $out/bin
          cp -r $src/assets $out/bin
        '';

        CARGO_BUILD_TARGET = "wasm32-unknown-unknown";
      };

      legacyPackages.wasm-publish = pkgs.stdenv.mkDerivation {
        pname = package_name;
        version = package_version;

        src = self.wasm32-unknown-unknown.${system}.outPath;

        htmlFile = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/bevyengine/bevy/e88e394feb506d686b90b20090cc055f2c31baa9/examples/wasm/index.html";
          sha256 = "sha256-BH74k0NA5zAH3oBKB6JuSuVJMMPYtjBsP+iHRK9cEoQ=";
        };

        buildInputs = with pkgs; [
          wasm-bindgen-cli
        ];

        preBuild = ''
          mkdir -p $out/public
          cp -r $src/bin/assets $out/public

          cat $htmlFile > $out/public/index.html
          sed -i "s,target/wasm_example.js,${package_name}.js,g" $out/public/index.html

          wasm-bindgen --out-dir $out/public --target web $src/bin/${package_name}.wasm
        '';
      };

      devShell = with pkgs;
        mkShell {
          buildInputs =
            [
              rust-analyzer
              rustfmt
              git-lfs
              # Used for datagraphs and SVG generation in the editor.
              graphviz
            ]
            ++ neededDeps;

          nativeBuildInputs =
            [
              toolchain
            ]
            ++ neededNativeDeps;

          RUST_SRC_PATH = rustPlatform.rustLibSrc;
          LD_LIBRARY_PATH = libPath;
        };
    });
}
