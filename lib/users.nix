{...}: {
  deploy = {
    mkUser = {...} @ args:
      {
        group = "deploy";
        description = "Deploy User (${args.name})";
        isNormalUser = true;
        openssh.authorizedKeys.keys = [
          # "set your own key here"
        ];
      }
      // args;
    mkSudoRules = name: [
      {
        users = [name];
        commands = [
          {
            command = "ALL";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];
    mkDoasRules = name: [
      {
        users = [name];
        noPass = true;
      }
    ];
    mkNixSettings = name: {
      allowed-users = [name];
      trusted-users = [name];
    };
  };
  operator = {
    mkUser = {...} @ args:
      {
        group = "adm";
        description = "Operator User (${args.name})";
        isNormalUser = true;
        extraGroups = ["wheel"];
        openssh.authorizedKeys.keys = [
          # "set your own key here"
        ];
      }
      // args;
    mkSudoRules = name: [
      {
        users = [name];
        commands = [
          {
            command = "ALL";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];
    mkDoasRules = name: pkgs: [
      {
        users = [name];
        cmd = "${pkgs.systemd}/bin/journalctl";
        noPass = true;
      }
      {
        users = [name];
        cmd = "${pkgs.systemd}/bin/machinectl";
        noPass = true;
      }
      {
        users = [name];
        cmd = "${pkgs.systemd}/bin/systemctl";
        noPass = true;
      }
      {
        users = [name];
        persist = true;
      }
    ];
  };
}
