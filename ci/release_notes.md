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



[bolo-release]: https://github.com/bolo/bolo/releases/tag/v0.3.0
