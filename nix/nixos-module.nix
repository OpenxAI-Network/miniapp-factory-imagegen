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

    systemd.services.miniapp-factory-imagegen =
      let
        diffusion = pkgs.fetchgit {
          name = "Qwen/Qwen-Image";
          url = "https://huggingface.co/Qwen/Qwen-Image";
          branchName = "main";
          fetchLFS = true;
          sha256 = "sha256-KqJuuHo3yoadzUFJs9uTPWgvozZSUiCAw0kiiqXM11I=";
        };
        lora = pkgs.fetchurl {
          name = "lightx2v/Qwen-Image-Lightning/Qwen-Image-Lightning-4steps-V2.0.safetensors";
          url = "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V2.0.safetensors";
          sha256 = "sha256-h4xRm3WqoZxfN+9XsxKsA16Tago2sU4CJp6d/VPSwig=";
        };
      in
      {
        description = "Image generation server for Miniapp Factory";
        serviceConfig = {
          ExecStart = "${lib.getExe miniapp-factory-imagegen} --diffusion=${diffusion} --lora=${lora}";
          User = "miniapp-factory-imagegen";
          Group = "miniapp-factory-imagegen";
          StateDirectory = "miniapp-factory-imagegen";
        };
      };
  };
}
