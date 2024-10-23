{
  config,
  profiles,
  ...
}: {
  imports = with profiles; [
    # NOTE: infinite recursion when used in lib.nixosSystem
    #kserv.virt.podman.basic
    #kserv.virt.podman.registries
  ];
  users.users.test-operator.extraGroups = ["podman"];
  # Arion
  virtualisation.arion = {
    backend = "podman-socket";
    projects.external.settings.imports = [
      #(import ./jellyfin.nix config)
      (import ./traefik config)
      (import ./funkwhale.nix config)
    ];
  };
  #systemd.services.arion-external.environment.DOCKER_HOST = "unix:///run/podman/podman.sock";
  environment.etc."podman/traefik/traefik.yml".source = ./traefik/traefik.yml;
  environment.etc."podman/traefik/config.yml".source = ./traefik/config.yml;
}
