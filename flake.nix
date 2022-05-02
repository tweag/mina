{
  description = "A very basic flake";
  nixConfig = {
    allow-import-from-derivation = "true";
    extra-substituters = [ "https://mina-demo.cachix.org" ];
    extra-trusted-public-keys =
      [ "mina-demo.cachix.org-1:PpQXDRNR3QkXI0487WY3TDTk5+7bsOImKj5+A79aMg8=" ];
  };

  inputs.utils.url = "github:gytis-ivaskevicius/flake-utils-plus";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";

  inputs.mix-to-nix.url = "github:serokell/mix-to-nix";
  inputs.nix-npm-buildPackage.url = "github:serokell/nix-npm-buildpackage";
  inputs.opam-nix.url = "github:tweag/opam-nix";
  inputs.opam-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.opam-nix.inputs.opam-repository.follows = "opam-repository";

  inputs.opam-repository.url = "github:ocaml/opam-repository";
  inputs.opam-repository.flake = false;

  inputs.nixpkgs-mozilla.url = "github:mozilla/nixpkgs-mozilla";
  inputs.nixpkgs-mozilla.flake = false;

  # For nix/compat.nix
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.gitignore-nix.url = "github:hercules-ci/gitignore.nix";
  inputs.gitignore-nix.inputs.nixpkgs.follows = "nixpkgs";

  inputs.nix-filter.url = "github:numtide/nix-filter";

  inputs.flake-buildkite-pipeline.url = "github:tweag/flake-buildkite-pipeline";

  outputs = inputs@{ self, nixpkgs, utils, mix-to-nix, nix-npm-buildPackage
    , opam-nix, opam-repository, nixpkgs-mozilla, flake-buildkite-pipeline, ...
    }:
    {
      overlay = import ./nix/overlay.nix;
      pipeline = with flake-buildkite-pipeline.lib; {
        steps = flakeStepsCachix {
          pushToBinaryCaches = [ "mina-demo" ];
          commonExtraStepConfig.agents = [ "nix" ];
        } self;
      };
    } // utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend
          (nixpkgs.lib.composeManyExtensions [
            (import nixpkgs-mozilla)
            (import ./nix/overlay.nix)
            (final: prev: {
              ocamlPackages_mina = requireSubmodules (import ./nix/ocaml.nix {
                inherit inputs pkgs;
                static = final.stdenv.hostPlatform.isStatic;
              });
            })
          ]);
        inherit (pkgs) lib;
        mix-to-nix = pkgs.callPackage inputs.mix-to-nix { };
        nix-npm-buildPackage = pkgs.callPackage inputs.nix-npm-buildPackage { };

        submodules = map builtins.head (builtins.filter lib.isList
          (map (builtins.match "	path = (.*)")
            (lib.splitString "\n" (builtins.readFile ./.gitmodules))));

        requireSubmodules = lib.warnIf (!builtins.all builtins.pathExists
          (map (x: ./. + "/${x}") submodules)) ''
            Some submodules are missing, you may get errors. Consider one of the following:
            - run nix/pin.sh and use "mina" flake ref;
            - use "git+file://$PWD?submodules=1";
            - use "git+https://github.com/minaprotocol/mina?submodules=1";
            - use non-flake commands like nix-build and nix-shell.
          '';

        checks = import ./nix/checks.nix inputs pkgs;

        ocamlPackages = pkgs.ocamlPackages_mina;
        ocamlPackages_static = pkgs.pkgsStatic.ocamlPackages_mina;
      in {

        # Jobs/Lint/Rust.dhall
        packages.trace-tool = pkgs.rustPlatform.buildRustPackage rec {
          pname = "trace-tool";
          version = "0.1.0";
          src = ./src/app/trace-tool;
          cargoLock.lockFile = ./src/app/trace-tool/Cargo.lock;
        };

        # Jobs/Lint/ValidationService
        # Jobs/Test/ValidationService
        packages.validation = ((mix-to-nix.override {
          beamPackages = pkgs.beam.packagesWith pkgs.erlangR22; # todo: jose
        }).mixToNix {
          src = ./src/app/validation;
          # todo: think about fixhexdep overlay
          # todo: dialyze
          overlay = (final: previous: {
            goth = previous.goth.overrideAttrs
              (o: { preConfigure = "sed -i '/warnings_as_errors/d' mix.exs"; });
          });
        }).overrideAttrs (o: {
          # workaround for requiring --allow-import-from-derivation
          # during 'nix flake show'
          name = "coda_validation-0.1.0";
          version = "0.1.0";
        });

        # Jobs/Release/LeaderboardArtifact
        packages.leaderboard = nix-npm-buildPackage.buildYarnPackage {
          src = ./frontend/leaderboard;
          yarnBuildMore = "yarn build";
          # fix reason
          yarnPostLink = pkgs.writeScript "yarn-post-link" ''
            #!${pkgs.stdenv.shell}
            ls node_modules/bs-platform/lib/*.linux
            patchelf \
              --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              --set-rpath "${pkgs.stdenv.cc.cc.lib}/lib" \
              ./node_modules/bs-platform/lib/*.linux ./node_modules/bs-platform/vendor/ninja/snapshot/*.linux
          '';
          # todo: external stdlib @rescript/std
          preInstall = ''
            shopt -s extglob
            rm -rf node_modules/bs-platform/lib/!(js)
            rm -rf node_modules/bs-platform/!(lib)
            rm -rf yarn-cache
          '';
        };

        # TODO: fix bs-platform build correctly
        packages.client_sdk = nix-npm-buildPackage.buildYarnPackage {
          name = "client_sdk";
          src = ./frontend/client_sdk;
          yarnPostLink = pkgs.writeScript "yarn-post-link" ''
            #!${pkgs.stdenv.shell}
            ls node_modules/bs-platform/lib/*.linux
            patchelf \
              --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              --set-rpath "${pkgs.stdenv.cc.cc.lib}/lib" \
              ./node_modules/bs-platform/lib/*.linux ./node_modules/bs-platform/vendor/ninja/snapshot/*.linux
          '';
          yarnBuildMore = ''
            cp ${ocamlPackages.mina_client_sdk}/share/client_sdk/client_sdk.bc.js src
            yarn build
          '';
          installPhase = ''
            mkdir -p $out/share/client_sdk
            mv src/*.js $out/share/client_sdk
          '';
        };

        inherit ocamlPackages ocamlPackages_static;
        packages.mina = ocamlPackages.mina;
        packages.mina_tests = ocamlPackages.mina_tests;
        packages.mina_ocaml_format = ocamlPackages.mina_ocaml_format;
        packages.mina_client_sdk_binding = ocamlPackages.mina_client_sdk;
        packages.mina-docker = pkgs.dockerTools.buildImage {
          name = "mina";
          contents = [ ocamlPackages.mina.out ];
        };
        packages.mina-daemon-docker = pkgs.dockerTools.buildImage {
          name = "mina-daemon";
          contents = [
            pkgs.dumb-init
            pkgs.coreutils
            pkgs.bashInteractive
            pkgs.python3
            pkgs.libp2p_helper
            ocamlPackages.mina.out
            ocamlPackages.mina.mainnet
            ocamlPackages.mina.genesis
            ocamlPackages.mina_build_config
            ocamlPackages.mina_daemon_scripts
          ];
          config = {
            env = [ "MINA_TIME_OFFSET=0" ];
            cmd = [ "/bin/dumb-init" "/entrypoint.sh" ];
          };
        };
        # packages.mina_static = ocamlPackages_static.mina;
        packages.marlin_plonk_bindings_stubs = pkgs.marlin_plonk_bindings_stubs;
        packages.go-capnproto2 = pkgs.go-capnproto2;
        packages.libp2p_helper = pkgs.libp2p_helper;
        packages.mina_integration_tests = ocamlPackages.mina_integration_tests;

        legacyPackages.musl = pkgs.pkgsMusl;
        legacyPackages.regular = pkgs;

        defaultPackage = ocamlPackages.mina;
        packages.default = ocamlPackages.mina;

        devShell = ocamlPackages.mina;
        devShells.default = ocamlPackages.mina;
        packages.impure-shell =
          (import ./nix/impure-shell.nix pkgs).inputDerivation;
        devShells.impure = import ./nix/impure-shell.nix pkgs;

        inherit checks;
      });
}
