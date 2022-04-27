inputs: pkgs:
let
  mina = inputs.self.packages.${pkgs.system}.default;

  mina' = import ./modules/mina.nix inputs;

  # Override the nixpkgs-provided defaults
  inherit (pkgs.lib) mkOverride carthesianProductOfSets;
  mkDefault = mkOverride 999;

  defaults = {
    time.timeZone = mkDefault "UTC";
    virtualisation = {
      memorySize = mkDefault 8192;
      diskSize = mkDefault 4096;
    };
  };

  seed-node = {
    services.mina = {
      enable = true;
      external-ip = "0.0.0.0";
      extraArgs = [ "--seed" ];
    };
  };

  seed-node-defaults = { imports = [ defaults mina' seed-node ]; };

  block-producer =
    let block-producer-key = "/var/lib/mina/keys/block-producer-key";
    in {
      environment.systemPackages = [ mina ];
      services.mina = {
        enable = true;
        extraArgs = [ "--block-producer-key" block-producer-key ];
      };
      systemd.services.mina = {
        environment.MINA_PRIVKEY_PASS = "naughty blue worm";
        preStart = ''
          if [ ! -f ${block-producer-key} ]; then
            mkdir -p $(dirname ${block-producer-key})
            ${mina.generate_keypair}/bin/generate_keypair --privkey-path ${block-producer-key}
            chmod 600 ${block-producer-key}
            chmod 700 $(dirname ${block-producer-key})
          fi
        '';
        postStart = ''
          mina accounts import \
            --config-directory /var/lib/mina \
            --privkey-path ${block-producer-key}
        '';
      };
    };

  block-producer-defaults = { imports = [ defaults mina' block-producer ]; };

  # Kind of a dirty hack, but what can you do...
  # This allows internet access inside the test VMs by using a fixed-output derivation which expects output "nonce"
  networkedTest = test: nonce:
    pkgs.lib.warn
    "Test ${test.name} requires networking and therefore may not be reproducible"
    (test.overrideAttrs (oa: {
      buildCommand = ''
        ${oa.buildCommand}
        rm -d $out
        echo -n ${pkgs.lib.escapeShellArg nonce} > $out
      '';
      outputHashAlgo = "sha256";
      outputHash = builtins.hashString "sha256" nonce;
    }));

  networkedTestNarHash = test:
    networkedTest test
    "${test.name} succeeded on ${inputs.self.sourceInfo.narHash}";
in {
  module-sanity-check = pkgs.nixosTest {
    name = "sanity-check";
    nodes.seed_node = seed-node-defaults;
    testScript = ''
      start_all()
      seed_node.wait_for_unit("mina.service")
      seed_node.succeed(
          '${mina}/bin/mina client status'
      )
    '';
  };

  gossip-consistency = networkedTestNarHash (pkgs.nixosTest {
    name = "gossip-consistency";
    nodes.node1.imports =
      [ block-producer-defaults { services.mina.extraArgs = [ "--seed" ]; } ];
    nodes.node2.imports = [
      block-producer-defaults
      { services.mina.peers = [ "/dns4/node1/tcp/8302/12D3KooWNG8JcntzQsRmLWK29oyG8nEVMBjT3VLd3FHjTm78u8ZG" ]; }
    ];
    testScript = ''
      start_all()
      node1.wait_for_unit("mina.service")
      node2.wait_for_unit("mina.service")

      node2.succeed("mina client send-payment --amount 10000000 --fee 10000000 --receiver node1")
    '';
  });

}
