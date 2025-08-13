{ pkgs, ... }:
{
  # is rootfull podman
  config.services = {
    webserver = {
      image.enableRecommendedContents = true;
      image.name = "localhost/webserver";
      service.useHostStore = true;
      service.user = "1234";
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
}
