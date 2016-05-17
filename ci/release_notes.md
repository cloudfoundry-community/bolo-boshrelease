## Bug Fixes

- Fix a bug that was prohibiting the agent from running on
  deployment VMs that had also colocated garden-linux or diego,
  because of a busybox mkdir segfault.
