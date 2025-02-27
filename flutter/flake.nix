{
  description = "Flutter mobile app";

  # Nixpkgs / NixOS version to use.
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.11";
    utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    fenix,
    utils,
  }:
    utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };

          overlays = [
            fenix.overlays.default
          ];
        };

        androidBuildToolsVersion = "33.0.1";

        androidComposition = pkgs.androidenv.composeAndroidPackages {
          toolsVersion = "26.1.1";
          platformToolsVersion = "33.0.3";
          buildToolsVersions = [androidBuildToolsVersion "30.0.3"];
          includeEmulator = false;
          emulatorVersion = "32.1.8";
          platformVersions = ["28" "29" "30" "31" "33"];
          includeSources = true;
          includeSystemImages = false;
          systemImageTypes = ["google_apis_playstore"];
          abiVersions = ["armeabi-v7a" "arm64-v8a"];
          cmakeVersions = ["3.22.1"];
          includeNDK = true;
          ndkVersions = ["25.1.8937393"];
          useGoogleAPIs = false;
          useGoogleTVAddOns = false;
          includeExtras = [
            "extras;google;gcm"
          ];
          extraLicenses = [
            "android-googletv-license"
            "android-sdk-arm-dbt-license"
            "android-sdk-license"
            "android-sdk-preview-license"
            "google-gdk-license"
            "intel-android-extra-license"
            "intel-android-sysimage-license"
            "mips-android-sysimage-license"
          ];
        };

        # Tools used for compiling the app for Linux
        linuxBuildTools = with pkgs; [
          at-spi2-core.dev
          clang
          cmake
          dbus.dev
          flutter
          gtk3
          libdatrie
          libepoxy.dev
          util-linux.dev
          libselinux
          libsepol
          libthai
          libxkbcommon
          ninja
          pcre
          pcre2.dev
          pkg-config
          xorg.libXdmcp
          xorg.libXtst
          libdeflate
          libsysprof-capture
        ];

        androidSdk = androidComposition.androidsdk;

        nativeBuildInputPackages = with pkgs; [
          llvmPackages_14.llvm
          llvmPackages_14.libunwind.dev
          pkg-config
          openssl
          binutils
          jdk11_headless
          glibc_multi
          libunwind.dev
        ];

        buildInputPackages = with pkgs;
          [
            libunwind.dev
            cargo-ndk
            androidComposition.androidsdk
            androidComposition.platform-tools
            git
            vscode
            unzip
            # gradle
            kotlin-language-server
            jdt-language-server
          ]
          ++ linuxBuildTools;
      in {
        devShell = pkgs.mkShell {
          nativeBuildInputs =
            nativeBuildInputPackages
            ++ [
              pkgs.rustPlatform.cargoSetupHook
              pkgs.rustPlatform.bindgenHook
            ];
          buildInputs = buildInputPackages
            ++ [
              pkgs.rustPlatform.cargoSetupHook
              pkgs.rustPlatform.bindgenHook
              pkgs.android-studio
            ];
          shellHook = ''
            unset ANDROID_NDK
            unset ANDROID_NDK_HOME

            export ANDROID_SDK_ROOT="${androidSdk}/libexec/android-sdk"
            export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk-bundle"
            export CPATH="${pkgs.glibc_multi.dev}/include"
            export LD_LIBRARY_PATH="${pkgs.libepoxy}/lib"
            export LIBCLANG_PATH="${pkgs.llvmPackages_14.libclang.lib}/lib"
          '';

          # Should fix Gradle errors
          GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/${androidBuildToolsVersion}/aapt2";
        };
      }
    );
}
