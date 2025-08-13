toplevel:
{ config, ... }:
let
  currJellyfinDir = "/docker/jellyfin";
  domain = "jellyfin.${toplevel.networking.domain}";
in
{
  # is rootfull podman
  config.services = {
    jellyfin.service = {
      image = "jellyfin/jellyfin:10.7.7";
      container_name = "jellyfin";
      restart = "unless-stopped";
      #group_add = [
      #  "video"
      #];
      networks = [
        "proxy"
      ];
      volumes = [
        "${currJellyfinDir}/config:/config"
        "${currJellyfinDir}/cache:/cache"
        #"/media/video:/data/tvshows"
        #"/media/music:/data/music"
        #"/media/downloads:/data/downloads"
      ];
      devices = [
        #"/dev/dri/renderD128:/dev/dri/renderD128"
        #"/dev/dri/card0:/dev/dri/card0"
      ];
      environment = {
        TZ = "Europe/Amsterdam";
        PUIG = "1001";
        PGID = "1001";
        JELLYFIN_PublishedServerUrl = "https://${domain}";
      };
      labels = {
        "traefik.enable" = "true";
        "traefik.docker.network" = "proxy";
        "traefik.http.routers.jellyfin.rule" = "Host(`${domain}`)";
        "traefik.http.routers.jellyfin.entrypoints" = "https";
        "traefik.http.routers.jellyfin.tls" = "true";
        "traefik.http.routers.jellyfin.middlewares" = "secured@file";
        "traefik.http.services.jellyfin.loadbalancer.server.port" = "8096";
      };
    };
  };
}
