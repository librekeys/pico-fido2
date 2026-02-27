{
  description = "Pico FIDO2 - FIDO2/OpenPGP firmware for Raspberry Pi Pico";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    pico-sdk = {
      url = "github:raspberrypi/pico-sdk/2.2.0";
      flake = false;
    };
    tinyusb = {
      url = "github:hathach/tinyusb/86ad6e56c1700e85f1c5678607a762cfe3aa2f47";
      flake = false;
    };

    pico-fido2 = {
      url = "github:librekeys/pico-fido2/75f50213998c325379d563f5736262276d3badbd";
      flake = false;
    };
    pico-openpgp = {
      url = "github:librekeys/pico-openpgp/822038aba29219e2fb48376a3ca2c1eb1af03059";
      flake = false;
    };
    pico-fido = {
      url = "github:librekeys/pico-fido/81d97f1a18856f73b0ffed50afeaf735cc2c1a54";
      flake = false;
    };
    pico-keys-sdk = {
      url = "github:librekeys/pico-keys-sdk/263e554cc6c59a5f168f8589c4bdabe6e1e64c25";
      flake = false;
    };

    mbedtls = {
      url = "github:Mbed-TLS/mbedtls/107ea89daaefb9867ea9121002fbbdf926780e98";
      flake = false;
    };
    mbedtls-eddsa = {
      url = "github:polhenarejos/mbedtls/mbedtls-3.6-eddsa";
      flake = false;
    };
    tinycbor = {
      url = "github:intel/tinycbor/c0aad2fb2137a31b9845fbaae3653540c410f215";
      flake = false;
    };
    mlkem = {
      url = "github:pq-code-package/mlkem-native/1453da5cd11ea6be7ae83d619d1a72b21e48ec7d";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    pico-sdk,
    tinyusb,
    pico-fido2,
    pico-fido,
    pico-openpgp,
    pico-keys-sdk,
    mbedtls,
    mbedtls-eddsa,
    tinycbor,
    mlkem,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

        picoSdk = pkgs.stdenvNoCC.mkDerivation {
          name = "pico-sdk-full";
          dontUnpack = true;
          dontFixup = true;
          installPhase = ''
            cp -r ${pico-sdk} $out
            chmod -R u+w $out
            rm -rf $out/lib/tinyusb
            cp -r ${tinyusb} $out/lib/tinyusb
          '';
        };

        buildTools = with pkgs; [
          cmake
          gcc-arm-embedded
          python3
          picotool
        ];

        mkPicoFido2 = {
          pname,
          mbedtlsSrc,
          product ? null,
          extraCmakeFlags ? [],
          extraDescription ? "",
        }: let
          vidpidFlag = pkgs.lib.optionals (product != null) [
            "-DVIDPID=${product}"
          ];
        in
          pkgs.stdenvNoCC.mkDerivation {
            inherit pname;
            version = "7.2-4.2";

            src = pico-fido2;

            dontFixup = true;

            nativeBuildInputs = buildTools;

            postUnpack = ''
              chmod -R u+w $sourceRoot

              rm -rf $sourceRoot/pico-fido
              cp -r ${pico-fido} $sourceRoot/pico-fido

              rm -rf $sourceRoot/pico-openpgp
              cp -r ${pico-openpgp} $sourceRoot/pico-openpgp

              rm -rf $sourceRoot/pico-keys-sdk
              mkdir -p $sourceRoot/pico-keys-sdk
              cp -r ${pico-keys-sdk}/* $sourceRoot/pico-keys-sdk/
              chmod -R u+w $sourceRoot/pico-keys-sdk

              rm -rf $sourceRoot/pico-keys-sdk/mbedtls
              cp -r ${mbedtlsSrc} $sourceRoot/pico-keys-sdk/mbedtls

              rm -rf $sourceRoot/pico-keys-sdk/tinycbor
              cp -r ${tinycbor} $sourceRoot/pico-keys-sdk/tinycbor

              rm -rf $sourceRoot/pico-keys-sdk/mlkem
              cp -r ${mlkem} $sourceRoot/pico-keys-sdk/mlkem

              chmod -R u+w $sourceRoot
            '';

            configurePhase = ''
              cmake -S . -B build \
                -DPICO_SDK_PATH=${picoSdk} \
                -DPICO_BOARD=pico2 \
                -DCMAKE_BUILD_TYPE=MinSizeRel \
                ${pkgs.lib.concatStringsSep " \\\n              " (extraCmakeFlags ++ vidpidFlag)}
            '';

            buildPhase = ''
              cmake --build build -j$NIX_BUILD_CORES
            '';

            installPhase = ''
              mkdir -p $out
              cp build/pico_fido2*.uf2 $out/
            '';

            meta = with pkgs.lib; {
              description = "FIDO2/OpenPGP firmware for Raspberry Pi Pico${extraDescription}";
              homepage = "https://github.com/sst311212/pico-fido2";
              license = licenses.gpl3Only;
              platforms = platforms.all;
            };
          };
      in let
        products = [
          "NitroHSM"
          "NitroFIDO2"
          "NitroStart"
          "NitroPro"
          "Nitro3"
          "Yubikey5"
          "YubikeyNeo"
          "YubiHSM"
          "Gnuk"
          "GnuPG"
        ];
      in {
        packages =
          {
            pico-fido2 = mkPicoFido2 {
              pname = "pico-fido2";
              mbedtlsSrc = mbedtls;
            };

            # NOTE https://github.com/polhenarejos/pico-openpgp/releases/tag/v4.0-eddsa1
            # Important: EdDSA cannot work in ESP32, since Espressif uses its own MbedTLS fork.
            # This is an experimental release. It adds support for EdDSA with Ed25519 and Ed448 curves.
            # Since EdDSA is not officially approved by MbedTLS, it is considered experimental and in beta stage. Though it is deeply tested, it might contain bugs.
            # Use with caution.
            pico-fido2-eddsa = mkPicoFido2 {
              pname = "pico-fido2-eddsa";
              mbedtlsSrc = mbedtls-eddsa;
              extraCmakeFlags = ["-DENABLE_EDDSA=ON"];
              extraDescription = " (with experimental EdDSA support)";
            };
          }
          // pkgs.lib.genAttrs (map (f: "pico-fido2-${f}") products) (f:
            mkPicoFido2 {
              pname = "pico-fido2-${f}";
              mbedtlsSrc = mbedtls;
              product = f;
            })
          // pkgs.lib.genAttrs (map (f: "pico-fido2-eddsa-${f}") products) (f:
            mkPicoFido2 {
              pname = "pico-fido2-eddsa-${f}";
              mbedtlsSrc = mbedtls-eddsa;
              product = f;
              extraCmakeFlags = ["-DENABLE_EDDSA=ON"];
              extraDescription = " (with experimental EdDSA support)";
            });

        defaultPackage = self.packages.${system}.pico-fido2;

        devShells.default = pkgs.mkShell {
          packages = buildTools;
        };
      }
    );
}
