localFlake @ {flake-parts-lib, ...}: {
  # imports = [ (flake-parts-lib.importApply ./flakeModule.nix localFlake) ];
  flake.nixosModules'.provision.scripts = ./nixosModule.nix;
  flake.homeModulesFlakeArgs = localFlake;
  flake.homeModules.provision.scripts = ./homeModule.nix;

  perSystem = {pkgs, ...}: {
    scripts.defaultLibDirs = ./nu;
    scripts.scripts = {
      ssh-fpscan.inputs = [pkgs.openssh];
      ssh-fpscan.text = ''
        # scan ssh fingerprints
        def main [
          host = localhost : string # host to scan
        ] {
          ssh-keyscan $host | ssh-keygen -lf -
        }
      '';
      logt = {
        inputs = [pkgs.lnav];
        file = ../scripts/nu/logt.nu;
      };
      iptools.nuModule = ../scripts/nu/iptools.nu;
      iplink.nuModule = ../scripts/nu/iplink.nu;
      flake-archive.file = ../scripts/nu/flake-archive.nu;
      ffmpeg-compress.inputs = [pkgs.ffmpeg-full];
      ffmpeg-compress.nuModule = ../scripts/nu/ffmpeg-compress.nu;
      dest.nuModule = ../scripts/nu/dest.nu;
      misc.nuModule = ../scripts/nu/misc.nu;
      mynft.nuModule = ../scripts/nu/mynft.nu;
      myarion.nuModule = ../scripts/nu/myarion.nu;
      sanu.nuModule = ../scripts/nu/sanu.nu;
      simple-replace.file = ../scripts/nu/simple-replace.nu;
      symlink-farm.nuModule = ../scripts/nu/symlink-farm.nu;
      remote-test.file = ../scripts/nu/remote-test.nu;
      mynix-diff.nuModule = ../scripts/nu/mynix-diff.nu;
    };
  };
}
