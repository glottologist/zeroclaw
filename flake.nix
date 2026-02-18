{
  description = "ZeroClaw – zero-overhead autonomous agent runtime";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) lib;
          fs = lib.fileset;
        in
        rec {
          zeroclaw = pkgs.rustPlatform.buildRustPackage {
            pname = "zeroclaw";
            version = "0.1.0";

            src = fs.toSource {
              root = ./.;
              fileset = fs.intersection (fs.gitTracked ./.) (
                fs.unions [
                  ./Cargo.toml
                  ./Cargo.lock
                  ./src
                  ./crates
                  ./benches
                  ./firmware
                ]
              );
            };

            cargoLock.lockFile = ./Cargo.lock;

            # Tests require network and port binding unavailable in the Nix sandbox
            doCheck = false;

            nativeBuildInputs = with pkgs; [
              pkg-config
            ];

            buildInputs =
              lib.optionals pkgs.stdenv.hostPlatform.isDarwin (
                with pkgs.darwin.apple_sdk.frameworks;
                [
                  Security
                  SystemConfiguration
                ]
                ++ [ pkgs.libiconv ]
              );

            useNextest = true;

            meta = {
              description = "Zero overhead autonomous agent runtime";
              homepage = "https://github.com/zeroclaw-labs/zeroclaw";
              license = lib.licenses.mit;
              maintainers = [ ];
              mainProgram = "zeroclaw";
            };
          };

          default = zeroclaw;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.zeroclaw ];

            nativeBuildInputs = with pkgs; [
              cargo
              rustc
              clippy
              rustfmt
              rust-analyzer
              cargo-nextest
            ];
          };
        }
      );

      overlays.default = _final: prev: {
        zeroclaw = prev.callPackage (
          {
            lib,
            rustPlatform,
            pkg-config,
            stdenv,
            darwin,
            libiconv,
          }:
          rustPlatform.buildRustPackage {
            pname = "zeroclaw";
            version = "0.1.0";

            src = self;

            cargoLock.lockFile = "${self}/Cargo.lock";

            doCheck = false;

            nativeBuildInputs = [ pkg-config ];

            buildInputs =
              lib.optionals stdenv.hostPlatform.isDarwin (
                with darwin.apple_sdk.frameworks;
                [
                  Security
                  SystemConfiguration
                ]
                ++ [ libiconv ]
              );

            useNextest = true;

            meta = {
              description = "Zero overhead autonomous agent runtime";
              homepage = "https://github.com/zeroclaw-labs/zeroclaw";
              license = lib.licenses.mit;
              maintainers = [ ];
              mainProgram = "zeroclaw";
            };
          }
        ) { };
      };
    };
}
