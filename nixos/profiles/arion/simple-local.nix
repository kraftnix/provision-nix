{
  profiles,
  pkgs,
  ...
}: {
  imports = with profiles; [
    kserv.virt.podman.basic
    kserv.virt.podman.registries
  ];
  users.users.kadmin.extraGroups = ["podman"];
  # Arion
  virtualisation.arion = {
    backend = "podman-socket";
    projects = {
      test = {
        settings = {
          imports = [
            ({...}: {
              # is rootfull podman
              config.services = {
                webserver = {
                  image.enableRecommendedContents = true;
                  image.name = "localhost/webserver";
                  service.useHostStore = true;
                  service.command = [
                    "sh"
                    "-c"
                    ''
                      cd "$$WEB_ROOT"
                      ${pkgs.python3}/bin/python -m http.server
                    ''
                  ];
                  service.ports = [
                    "8000:8000" # host:container
                  ];
                  service.environment.WEB_ROOT = "${pkgs.nix.doc}/share/doc/nix/manual";
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
