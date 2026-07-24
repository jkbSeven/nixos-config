{
  lib,
  ...
}:

{
  options.homelab.settings = lib.mkOption {
    type = lib.types.attrs;
  };
}
