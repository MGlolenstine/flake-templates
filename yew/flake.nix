{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk.url = "github:nix-community/naersk/master";
   };

  outputs = { self, nixpkgs, utils, naersk, fenix, ... }:
    utils.lib.eachDefaultSystem (system: 
      let
        pname = "trunk-template";
        version = "0.1.0";

        pkgs = import nixpkgs{
          inherit system;
        };

        rustToolchain = "stable";
        rustHash = "sha256-yMuSb5eQPO/bHv+Bcf/US8LVMbf/G/0MSfiPwBhiPpk=";

        stableToolchain = fenix.packages.${system}.toolchainOf{
            channel = rustToolchain;
            sha256 = rustHash;
          };

        wasmToolchain = fenix.packages.${system}.targets.wasm32-unknown-unknown.toolchainOf{
            channel = rustToolchain;
            sha256 = rustHash;
        };

        toolchain = with fenix.packages.${system}; combine [
          stableToolchain.cargo
          stableToolchain.rustc
          stableToolchain.rustfmt
          stableToolchain.clippy
          wasmToolchain.rust-std
        ];
       
        buildInputs = with pkgs;[
          toolchain
          
          trunk
          wasm-bindgen-cli
          dart-sass
          tailwindcss
          
          # For wasm-opt
          binaryen

          # For sha384sum
          coreutils
        ];

        naersk' = pkgs.callPackage naersk {
          cargo = toolchain;
          rustc = toolchain;
        };

      in {
        defaultPackage = pkgs.stdenv.mkDerivation { 
          inherit pname version;
          inherit buildInputs;

          src = ./.;

          configurePhase = ''
            mkdir -p $out/dist
          '';

          installPhase = ''
            # Build WASM executable
            # cargo build --target=wasm32-unknown-unknown --manifest-path $src/Cargo.toml

            # Compile the SASS file into CSS
            sass --embed-source-map --style expanded $src/index.scss $out/dist/index.css

            # Create JS bindings for the WASM binary
            wasm-bindgen --target=web --out-dir=$out/dist --out-name=${pname} ${self.packages.${system}.wasm_binary}/bin/${pname}.wasm --no-typescript

            export CSS_INTEGRITY=$(sha384sum $out/dist/index.css | cut -d' ' -f1)
            export JS_INTEGRITY=$(sha384sum $out/dist/${pname}.js | cut -d' ' -f1)
            export WASM_INTEGRITY=$(sha384sum $out/dist/${pname}_bg.wasm | cut -d' ' -f1)

            # Generate HTML
            echo "<!DOCTYPE html>
            <html>
              <head>
                <meta charset=\"utf-8\" />
                <title>Trunk Template</title>
                <link rel=\"stylesheet\" href=\"/index.css\" integrity=\"$CSS_INTEGRITY\"/>

            <link rel=\"modulepreload\" href=\"/${pname}.js\" crossorigin=anonymous integrity=\"$JS_INTEGRITY\">
            <link rel=\"preload\" href=\"/${pname}_bg.wasm\" crossorigin=anonymous integrity=\"$WASM_INTEGRITY\" as=\"fetch\" type=\"application/wasm\"></head>
              <body>

            <script type=\"module\">
            import init, * as bindings from '/${pname}.js';
            const wasm = await init('/${pname}_bg.wasm');

            window.wasmBindings = bindings;

            dispatchEvent(new CustomEvent(\"TrunkApplicationStarted\", {detail: {wasm}}));

            </script></body>
            </html>
            " > $out/dist/index.html
          '';

          # Skip the unpack step (mkDerivation will complain otherwise)  
          # dontUnpack = true;
        };

        packages.wasm_binary = naersk'.buildPackage {
          src = ./.;
          CARGO_BUILD_TARGET="wasm32-unknown-unknown";
        };
      
        devShell = with pkgs; mkShell {
          inherit buildInputs;
          NODE_OPTIONS="--openssl-legacy-provider";
        };
      });
}
