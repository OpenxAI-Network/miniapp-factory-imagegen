{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.miniapp-factory-imagegen;
  miniapp-factory-imagegen = pkgs.callPackage ./package.nix { };
in
{
  options = {
    services.miniapp-factory-imagegen = {
      enable = lib.mkEnableOption "Enable the python app";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.miniapp-factory-imagegen = { };
    users.users.miniapp-factory-imagegen = {
      isSystemUser = true;
      group = "miniapp-factory-imagegen";
    };

    systemd.services.miniapp-factory-imagegen = {
      description = "Image generation server for Miniapp Factory";
      environment = {
        PYTHONUNBUFFERED = "1";
      };
      serviceConfig = {
        ExecStart = "${lib.getExe miniapp-factory-imagegen}";
        User = "miniapp-factory-imagegen";
        Group = "miniapp-factory-imagegen";
        StateDirectory = "miniapp-factory-imagegen";
      };
    };
  };
}
