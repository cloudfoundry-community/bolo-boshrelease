## New Features

- Renamed all default graphs to use hyphens instead of underscores
  to separate name components.
- Added new graphs for process, nginx, rrdcached and postgres
  metrics.

## Bug Fixes

- Custom Graphs work again!
- Run dbolo as root, so that it can monitor other processes,
  files, etc., whether they are owned by root, vcap or any other
  user.
