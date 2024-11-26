{
  self,
  lib,
  ...
}:
{ config, ... }:
{
  # _module.args = {
  #   #inherit (self) nixosModules profiles hmProfiles hmModules;
  #   nixosModules = lib.optionalAttrs (self ? nixosModules) self.nixosModules;
  #   profiles = lib.optionalAttrs (self ? profiles) self.profiles;
  #   # hmProfiles = lib.optionalAttrs (self ? hmProfiles) self.hmProfiles;
  #   # hmModules = lib.optionalAttrs (self ? hmModules) self.hmModules;
  # };
}
