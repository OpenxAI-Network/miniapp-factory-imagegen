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

      git = lib.mkOption {
        type = lib.types.package;
        default = pkgs.git;
        example = pkgs.git;
        description = ''
          git equivalent executable to use for project updates.
        '';
      };
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
        GIT = "${cfg.git}/bin/";
      };
      serviceConfig = {
        ExecStart = "${lib.getExe miniapp-factory-imagegen}";
        User = "miniapp-factory-imagegen";
        Group = "miniapp-factory-imagegen";
        StateDirectory = "miniapp-factory-imagegen";
      };
    };

    programs.git = {
      enable = true;
      config = {
        user.name = "Mini App Factory";
        user.email = "miniapp-factory@openxai.org";
        github.user = "miniapp-factory";
        hub.protocol = "ssh";
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        url."git@github.com:".insteadOf = [
          "https://github.com/"
          "github:"
        ];
        core.sshCommand = "${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no -i /var/lib/miniapp-factory-imagegen/.ssh/id_ed25519";
      };
    };
  };
}
