toplevel: {config, ...}: let
  currDir = "/etc/podman/traefik";
  #domain = "traefik.${toplevel.networking.domain}";
in {
  # is rootfull podman
  config.docker-compose.raw = {
    networks.proxy = {
      name = "proxy";
      #internal = true;
      #external = true;
    };
    networks.external = {
      name = "external";
      #external = true;
      ipam = {
        driver = "default";
        config = [
          {
            subnet = "172.31.0.0/16";
            ip_range = "172.31.5.0/24";
            gateway = "172.31.5.1";
          }
        ];
      };
    };
  };
  config.services = {
    traefik.out.service.networks = {
      proxy = {};
      external = {
        ipv4_address = "172.31.5.2";
        #ports = [
        #  "8080:80"
        #  "8082:82"
        #  "4443:443"
        #];
      };
    };
    traefik.service = {
      image = "traefik:v2.4.7";
      container_name = "traefik";
      restart = "unless-stopped";
      ports = [
        "80:80"
        "443:443"
      ];
      volumes = [
        #"/var/run/docker.sock:/var/run/docker.sock:ro"
        "/run/podman/podman.sock:/var/run/docker.sock:ro"
        "${currDir}/traefik.yml:/traefik.yml:ro"
        "${currDir}/config.yml:/config.yml:ro"
        #"${currDir}/certs:/certs:ro"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.docker.network" = "proxy";
        "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme" = "https";
        "traefik.http.middlewares.redirect-to-https.redirectscheme.permanent" = "true";
        "traefik.http.routers.redirs.rule" = "hostregexp(`{10.1.1.2:.+}`) || hostregexp(`{home.lan:.+}`)";
        "traefik.http.routers.redirs.entrypoints" = "http";
        "traefik.http.routers.redirs.middlewares" = "redirect-to-https";
        #"traefik.entryPoints.http.address" = ":80";
        #"traefik.entryPoints.http.proxyProtocol.trustedIPs = "
      };
    };
  };
}
