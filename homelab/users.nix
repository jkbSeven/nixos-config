/*
Source of truth for user and group ids.

This is necessary for syncing ids between hosts that are not nix-managed, e.g. a TrueNAS instance.
*/
{
  nextcloud = {
    uid = 4000;
    gid = 4000;
  };
}
