inputs:
{ pkgs, lib, config, ... }: {
  options = with lib;
    with types; {
      services.mina = {
        enable = mkEnableOption
          "the daemon for Mina, a lightweight, constant-size blockchain";
        config = lib.mkOption {
          type = attrs;
          default = { };
        };
        package = lib.mkOption {
          type = package;
          default = inputs.self.packages.${pkgs.system}.default;
        };
        client-port = lib.mkOption {
          type = port;
          default = 8301;
        };
        external-port = lib.mkOption {
          type = port;
          default = 8302;
        };
        rest-port = lib.mkOption {
          type = port;
          default = 3085;
        };
        external-ip = lib.mkOption {
          type = nullOr
            (strMatching "[0-9]{0,3}[.][0-9]{0,3}[.][0-9]{0,3}[.][0-9]{0,3}");
          default = null;
        };
        protocol-version = lib.mkOption {
          type = nullOr (strMatching "[0-9]+[.][0-9]+[.][0-9]+");
          default = null;
        };
        log-level = lib.mkOption {
          type = enum [
            "Spam"
            "Trace"
            "Debug"
            "Info"
            "Warn"
            "Error"
            "Faulty_peer"
            "Fatal"
          ];
          default = "Info";
        };
        disable-node-status = lib.mkOption {
          type = bool;
          default = false;
        };
        peers = lib.mkOption {
          type = listOf (strMatching "/[^/]+/[^/]+/[^/]+/[^/]+/[^/]+/[^/]+");
          default = [];
        };

        waitForRpc = lib.mkOption {
          type = bool;
          default = true;
        };
        extraArgs = lib.mkOption {
          type = listOf str;
          default = [ ];
        };
      };
    };

  config = let
    cfg = config.services.mina;
    config-file = pkgs.writeText "config.json" (builtins.toJSON cfg.config);
    inherit (lib) escapeShellArg optionalString optional;
    optionalFlag = opt:
      optionalString (!isNull cfg.${opt}) "--${opt} ${cfg.${opt}}";
  in {
    networking.firewall.allowedTCPPorts = [ cfg.external-port ];
    systemd.services.mina = lib.mkIf cfg.enable {
      wantedBy = [ "multi-user.target" ];
      path = [ cfg.package ] ++ optional cfg.waitForRpc pkgs.netcat;
      script = ''
        mina daemon \
          --config-file ${config-file} \
          --config-dir "$STATE_DIRECTORY" \
          --working-dir "$STATE_DIRECTORY" \
          --log-level ${cfg.log-level} \
          --external-port ${toString cfg.external-port} \
          --client-port ${toString cfg.client-port} \
          --rest-port ${toString cfg.rest-port} \
          ${optionalFlag "external-ip"} \
          ${optionalFlag "protocol-version"} \
          ${optionalString cfg.disable-node-status "--disable-node-status"} \
          ${toString (map (peer: "--peer ${escapeShellArg peer}") cfg.peers)} \
          ${toString (map escapeShellArg cfg.extraArgs)} \
          &
        ${optionalString cfg.waitForRpc
        "until nc -z 127.0.0.1 ${toString cfg.client-port}; do sleep 1; done"}
      '';
      serviceConfig = {
        PrivateTmp = true;
        ProtectHome = "yes";
        DynamicUser = true;
        User = "mina";
        Group = "mina";
        StateDirectory = "mina";
        Type = "forking";
      };
    };
  };

}
