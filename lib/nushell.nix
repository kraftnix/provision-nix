{ lib, ... }:
with lib;
{
  writeNu =
    {
      nushell,
      configFile ? null,
      configCmds ? "",
      extra ? "",
    }:
    let
      base = "${nushell}/bin/nu";
      interpreter =
        if configFile != null then
          "${base} --config ${configFile} ${extra}"
        else if configCmds != "" then
          "${base} -c ${builtins.concatStringSep "; " configCmds} ${extra}"
        else
          "${base} ${extra}";
    in
    writers.makeScriptWriter {
      inherit interpreter;
    };
  writeNuBin = name: writeNu "/bin/${name}";
}
