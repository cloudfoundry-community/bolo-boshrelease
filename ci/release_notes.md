## Improvements

- Upgrade to [bolo v0.3.0][bolo-release].

- Per-subscriber submission and subscription address/port
  configuration are now gone, in favor of a globally-settable set
  of parameters.  This means that dbolo.submission.\*, and
  bolo.rrd.submission.\* are now just bolo.submission.\*.

- New `opentsdb` job for intercepting data submitted to an
  OpenTSDB endpoint and pulling it into the bolo aggregator.
  This can be used to pull health metrics from BOSH's TSDB
  submitter plugin.

- New `influxdb` job allows site operators to run a dedicated
  InfluxDB node in their bolo installation, and feed data from
  bolo into it.

- New `grafana` job can provide better visualization of data in
  bolo (by way of native OpenTSDB integration).

- New `slack` job let you get all those TRANSITION messages in
  your favorite Slack channel!


[bolo-release]: https://github.com/bolo/bolo/releases/tag/v0.3.0
