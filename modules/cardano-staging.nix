with (import ./../lib.nix);

params:
{ name, config, pkgs, resources, ... }: {
  imports = [
    ./staging.nix
    ./datadog.nix
    ./papertrail.nix
    ./monitoring-exporters.nix
  ];
  nixpkgs.overlays = [ (import ../overlays/monitoring-exporters.nix) ];
  
  global.dnsHostname = if params.typeIsRelay then "cardano-node-${toString params.relayIndex}" else null;
}
