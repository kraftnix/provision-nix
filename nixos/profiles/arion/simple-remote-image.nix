{profiles, ...}: {
  imports = with profiles; [
    kserv.virt.podman.basic
    kserv.virt.podman.registries
  ];
  users.users.kadmin.extraGroups = ["podman"];
  # Arion
  virtualisation.arion = {
    backend = "podman-socket";
    projects = {
      registry-image = {
        settings = {
          imports = [
            ({...}: {
              # is rootfull podman
              config.services = {
                jellyfin = {
                  service.image = "jellyfin/jellyfin:10.7.7";
                  service.ports = [
                    "8096:8096" # host:container
                  ];
                  #service.environment.WEB_ROOT = "${pkgs.nix.doc}/share/doc/nix/manual";
                  service.stop_signal = "SIGINT";
                };
              };
            })
          ];
        };
      };
    };
  };
}
