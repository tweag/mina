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
        enable-peer-exchange = lib.mkOption {
          type = bool;
          default = false;
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
          default = [ ];
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
    arg = opt:
      optionalString (!isNull cfg.${opt})
      "--${opt} ${escapeShellArg cfg.${opt}}";
    flag = opt: optionalString (!isNull cfg.${opt} && cfg.${opt}) "--${opt}";
    args = opt:
      toString (map (val: "--${opt} ${escapeShellArg val}") cfg."${opt}s");
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
          ${arg "log-level"} \
          ${arg "external-port"} \
          ${arg "client-port"} \
          ${arg "rest-port"} \
          ${arg "external-ip"} \
          ${arg "protocol-version"} \
          ${flag "disable-node-status"} \
          ${flag "enable-peer-exchange"} \
          ${args "peer"} \
          ${toString (map escapeShellArg cfg.extraArgs)} \
          &
        ${optionalString cfg.waitForRpc
        ''
          until nc -z 127.0.0.1 ${toString cfg.client-port}; do
            if ! jobs %% > /dev/null 2> /dev/null; then
              echo "Mina daemon crashed before the RPC socket is up"
              exit 1
            fi
            sleep 1
          done
        ''}
      '';
      serviceConfig = {
        PrivateTmp = true;
        ProtectHome = "yes";
        DynamicUser = true;
        User = "mina";
        Group = "mina";
        StateDirectory = "mina";
        Type = "forking";
        # Mina daemon can take a while to start up
        TimeoutStartSec = "15min";
      };
    };
  };

}
