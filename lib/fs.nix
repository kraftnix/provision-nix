{ lib, ... }:
with lib;
{
  btrfsMap =
    device: subvols:
    mapAttrs' (
      subvol: cfg:
      let
        filteredCfg = filterAttrs (opt: _: opt != "path" && opt != "isRoot") cfg;
        options =
          (optionals (!(cfg ? isRoot && cfg.isRoot)) [ "subvol=${subvol}" ])
          ++ (optionals (cfg ? options) cfg.options);
      in
      nameValuePair cfg.path (
        filteredCfg
        // {
          inherit device options;
          fsType = "btrfs";
        }
      )
    ) subvols;
}
