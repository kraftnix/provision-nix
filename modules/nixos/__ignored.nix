localFlake:
{ config, ... }:
{
  assertions = [
    {
      assertion = false;
      message = "You should not be importing this, it is used as a test to ensure auto-import ignores file __ignored.nix";
    }
  ];
}
