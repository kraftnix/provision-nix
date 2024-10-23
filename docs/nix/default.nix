{self, ...}: {
  imports = [./options.nix];
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    packages.docs-site-options = pkgs.stdenvNoCC.mkDerivation {
      name = "docs-site-options";
      nativeBuildInputs = [pkgs.nushell];
      src = pkgs.lib.cleanSourceWith {
        src = ./..;
        filter = path: type: baseNameOf (toString path) != "nix";
      };
      buildPhase = ''
        runHook preBuild

        cp -r . $out
        {
          while read ln; do
            case "$ln" in
              *end_of_intro*)
                break
                ;;
              *)
                echo "$ln"
                ;;
            esac
          done
          cat intro-continued.md
        } <${self.outPath + "/README.md"} >./intro.md
        cp ./intro.md $out/
        mkdir -p $out/options
        cp ${config.packages.options-filtered} $out/options/nixos-options.md
        runHook postBuild
      '';
    };
    packages.docs-site = pkgs.stdenvNoCC.mkDerivation {
      name = "docs-site";
      nativeBuildInputs = [pkgs.mdbook pkgs.mdbook-linkcheck];
      src = config.packages.docs-site-options;
      buildPhase = ''
        runHook preBuild

        mdbook build --dest-dir $TMPDIR/out
        cp -r $TMPDIR/out/html $out

        runHook postBuild
      '';
      dontInstall = true;
    };
  };
}
