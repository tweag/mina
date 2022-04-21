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
        external-port = lib.mkOption {
          type = port;
          default = 8302;
        };
        external-ip = lib.mkOption {
          type = nullOr
            (strMatching "[0-9]{0,3}[.][0-9]{0,3}[.][0-9]{0,3}[.][0-9]{0,3}");
          default = null;
        };
        protocol-version = lib.mkOption {
          type = nullOr (strMatching "[0-9]+[.][0-9]+[.][0-9]+");
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
  in {
    networking.firewall.allowedTCPPorts = [ cfg.external-port ];
    systemd.services.mina = lib.mkIf cfg.enable {
      wantedBy = [ "multi-user.target" ];
      path = [ cfg.package ];
      script = ''
        mina daemon \
          --config-file ${config-file} \
          --config-dir "$STATE_DIRECTORY" \
          --working-dir "$STATE_DIRECTORY" \
          --external-port ${toString cfg.external-port} \
          ${
            lib.optionalString (!isNull cfg.external-ip)
            "--external-ip ${cfg.external-ip}"
          } \
          ${toString (map lib.escapeShellArg cfg.extraArgs)}
      '';
      serviceConfig = {
        PrivateTmp = true;
        ProtectHome = "yes";
        DynamicUser = true;
        User = "mina";
        Group = "mina";
        StateDirectory = "mina";
      };
    };
  };

}
