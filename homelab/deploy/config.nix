{
  lib,
  inventory,
  nodes,
  ...
}:
{
  variable.token = { sensitive = true; };
  variable.domain = { default = inventory.domain; };
}
