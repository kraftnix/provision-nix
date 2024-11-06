{
  self,
  lib,
  ...
}: {
  # imports = [ inputs.emanote.flakeModule ];

  # devshells
  perSystem = {
    self',
    config,
    pkgs,
    ...
  }: let
    inherit (lib) replaceStrings;
    mkDocOptions = pkgs: let
      # # evaluate our options
      # eval = lib.evalModules {
      #   check = false;
      #   modules = lib.attrValues self.nixosModules;
      # };
      # generate our docs
      optionsDoc = pkgs.nixosOptionsDoc {
        # inherit (eval) options;
        options = removeAttrs self.nixosConfigurations.basic.options ["_module"];
        documentType = "none";
        markdownByDefault = true;
        transformOptions = option:
          option
          // {
            visible =
              option.visible
              && builtins.elemAt option.loc 0 == "provision"
              # NOTE: tofix
              && option.loc != ["provision" "scripts" "scripts" "<name>" "file"]
              && option.loc != ["provision" "nix" "flakes" "inputs"]
              && option.loc != ["provision" "fs" "zfs" "kernel" "latest"];
          };
      };
    in
      pkgs.runCommand "options-doc.md" {} ''
        cat ${optionsDoc.optionsCommonMark} >> $out
      '';

    ## Very Hacky sed replacements for internal modules
    sedFilterContainerCommonMark = {
      pkgs,
      file,
      outPath,
      siteRootPath ? "",
    }: let
      # escape args for usage with `sed`
      escapedNixStorePath = replaceStrings ["/"] ["\\/"] outPath;
      escapedSiteRootPath = replaceStrings ["/" "."] ["\\/" "\\."] siteRootPath;

      # `sed` filters
      removeNixStorePath = "s/${escapedNixStorePath}\\///";
      substituteSiteRoot = "s/file:\\/\\/${escapedNixStorePath}\\//${escapedSiteRootPath}/";
    in
      pkgs.runCommand "filter-opts-common-mark" {} ''
        ${pkgs.gnused}/bin/sed '${removeNixStorePath}' ${file} > path-filtered.md
        ${pkgs.gnused}/bin/sed '${substituteSiteRoot}' path-filtered.md > link-filtered.md
        cp link-filtered.md $out
      '';
  in {
    packages.options = mkDocOptions pkgs;
    packages.options-filtered = sedFilterContainerCommonMark {
      inherit pkgs;
      file = config.packages.options;
      outPath = self.outPath;
      siteRootPath = "https://github.com/kraftnix/provision-nix/tree/master/";
      # siteRootPath = "https://<gitea-url>/kraftnix/provision-nix/src/branch/master/";
    };
  };
}
