toplevel:
{ config, ... }:
let
  container = "funkwhale";
  #currDir = "/docker/${container}";
  currDir = "/docker/${container}";
  domain = "${container}.${toplevel.networking.domain}";
in
{
  # is rootfull podman
  config.services = {
    #funkwhale.image = {
    #  nixBuild = true;
    #  name = "funkwhale/all-in-one:1.1.4";
    #};
    funkwhale.service = {
      image = "funkwhale/all-in-one:1.1.4";
      container_name = container;
      restart = "unless-stopped";
      networks = [
        "proxy"
      ];
      volumes = [
        "${currDir}/data:/data"
        "/media/music:/music:ro"
      ];
      environment = {
        PUID = "1001";
        GUID = "1001";
        NESTED_PROXY = "1";
        FUNKWHALE_HOSTNAME = domain;
        FUNKWHALE_PROTOCOL = "https";
        MUSIC_DIRECTORY_PATH = "/music";
        MUSIC_DIRECTORY_SERVE_PATH = "/media/music";
        MEDIA_URL = "https://${domain}/media/";
      };
      labels = {
        "traefik.enable" = "true";
        "traefik.docker.network" = "proxy";
        "traefik.http.routers.${container}.rule" = "Host(`${domain}`)";
        "traefik.http.routers.${container}.entrypoints" = "https";
        "traefik.http.routers.${container}.tls" = "true";
        "traefik.http.routers.${container}.service" = container;
        "traefik.http.routers.${container}.middlewares" = "secured@file";
        "traefik.http.services.${container}.loadbalancer.server.port" = "80";
        "traefik.http.services.${container}.loadbalancer.passHostHeader" = "true";
      };
    };
  };
}
