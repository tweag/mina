inputs: pkgs:
let
  mina = import ./modules/mina.nix inputs;

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

  seed-node-defaults = { imports = [ defaults mina seed-node ]; };

  # Kind of a dirty hack, but what can you do...
  # This allows internet access inside the test VMs
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
          '${
            inputs.self.packages.${pkgs.system}.default
          }/bin/mina client status'
      )
    '';
  };

}
