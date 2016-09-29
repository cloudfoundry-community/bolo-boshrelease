# Improvements

- Upgraded to bolo-0.2.20 (from 0.2.17)
- Added `SET.KEYS` PDU counds to bolo-bogon and bolo-throughput
  gnossis graphs.

# Bug Fixes

- Required CPAN Perl modules are now included in this release, so
  that Perl collectors (mostly the SNMP ones) work out-of-the-box.
  (Fixes #6)

- Fix incorrect rrdcached socket path in `rrd` job
