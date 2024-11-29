{ lib, ... }:
let
  /**
    Apply the `mkOverride 990`, override level for provision-nix.

    # Example

    ```nix
    mkPDefault 1
    =>
    mkOverride 990 1
    ```

    # Type

    ```
    mkDefaults :: Any
    ```

    # Arguments

    conf
    : any item to apply mkOverride to
  */
  mkPDefault = lib.mkOverride 990;
in
{
  inherit mkPDefault;

  /**
    Apply the default `mkOverride 990` to each element of an attrs.

    # Example

    ```nix
    mkDefaults { hello = 1; }
    =>
    { hello = mkOverride 990 1; }
    ```

    # Type

    ```
    mkDefaults :: Attrs -> Attrs
    ```

    # Arguments

    attrs
    : attribute set to apply `mkOverride` to
  */
  mkDefaults = lib.mapAttrs (_: val: mkPDefault val);
}
