BOSH Release for bolo
=====================

bolo is a toolkit for building distributed, scalable monitoring
systems.  It provides a set of small, versatile components that
you can plug together in new and exciting ways, to gather and
aggregate metrics, mine data and track system states.

This repository packages [bolo][bolo], dbolo and the
[bolo-collectors][plugins] up into an easy-to-use BOSH release for
deploying monitoring to your BOSH deployments.

It provides both the server-side monitoring core functionality, as
well as a template for embedding the dbolo agent on all the VMs
you deploy via BOSH.

Getting Started on BOSH-lite
----------------------------

Before you can deploy bolo, you're going to need to upload this
BOSH release to your BOSH-lite, using the CLI:

    bosh target https://192.168.50.4:25555
    bosh upload release https://bosh.io/d/github.com/cloudfoundry-community/bolo-boshrelease

You can create a small, working manifest file from this git
repository:

    git clone https://github.com/cloudfoundry-community/bolo-boshrelease
    cd bolo-boshrelease
    ./templates/make_manifest warden
    bosh -n deploy

Once that's deployed, you can access the web interface at
[http://10.244.151.2](http://10.244.151.2).  It should look
something like this:

![Web Interface Screenshot][screen1]


Getting Started on vSphere
--------------------------

If you want to deploy a bolo core and some agents on your vSphere,
you can use [Genesis][genesis] and the [bolo-deployment][tpl]
template, which has site templates for vSphere:

    cd ~/ops
    genesis new deployment --template bolo/bolo-deployment bolo
    genesis new site --template vsphere my-site
    genesis new environment my-site my-env
    cd my-site/my-env

From here, you'll want to make sure your name is correct in
`name.yml`:

    ---
    name: my-bolo

and that your BOSH director's UUID is set in `directory.yml`:

    ---
    director_uuid: YOUR-DIRECTOR-UUID

From there, with your BOSH director targeted, you can deploy it:

    make deploy

In order to configure your other, non-Bolo deployments to submit
metrics to your shiny new Bolo deployment, read _Setting up
Agents_.


Setting up Agents
-----------------

In order to submit metrics from a deployment to Bolo, you just
need to add the release to the deployment manifest, add the
`dbolo` template to the job(s) in question, and set up the
`bolo.dbolo.submission` properties to maatch your installation.

    ---
    releases:
      - name:    bolo
        version: latest

    jobs:
      - name: first-job
        templates:
          - release: bolo
            name:    dbolo

    properties:
      bolo:
        dbolo:
          submission:
            address: 10.0.0.1   # <--- change this


Parts of a Bolo Deployment
--------------------------

Bolo provides the following job templates:

### bolo

This is the aggregator core.  It listens for inbound submission
traffic, metrics being sent in from the monitored hosts,
aggregates them, and then broadcasts them to all subscribers.

By default, metrics will be aggregated over a 60s window.  If
metrics are submitted every 20s, the aggregator will consolidate
three of the measurements into one, before broadcast.  You can
specify a different aggregation window (in seconds) with the
**bolo.window** property.

Bolo can track arbitrary states, for things like "is nginx up?".
This is done via `STATE` submissions, which are expected to be
given regularly and frequently.  If these submissions stop, the
aggregator will begin broadcasting staleness messages for those
states, after a freshness threshold is exceeded.  The
**bolo.freshness.threshold** property sets this.  You can also
change the **bolo.freshness.status** and
**bolo.freshness.message** properties to influence this behavior.

If you need to control what interfaces / IP addresses the core
uses for inbound submission of metrics (listener), management
(controller), or broadcast, you can set the following:

  - **bolo.listener.address**
  - **bolo.listener.port**
  - **bolo.management.address**
  - **bolo.management.port**
  - **bolo.broadcast.address**
  - **bolo.broadcast.port**


### dbolo

`dbolo` is a small, lightweight agent that is responsible for
regularly running collectors and submitting the resulting
measurements to a bolo aggregator.

To wire up a dbolo agent to a bolo core, you'll want to set the
**dbolo.submission.address** and **dbolo.submission.port**
properties (although you only need to change the port if you
changed it from the default in your bolo deployment).

Each measurement will be prefixed with a string to uniquely
identify the sender.  This prefix defaults to
`(deployment)-(job)-(index)`, which should suffice for most
configurations.  The keyword `(deployment)` will be replaced by
the name of the deployment that the VM belongs to; `(job)` will
become the name of the job (per the manifest), and `(index)` the
number of the instance (starting at 0).

To configure additional collectors, change the
**dbolo.collectors** property, for example:

    properties:
      dbolo:
        collectors:
          - { every: 20s, run: linux }
          - { every: 20s, run: process -n nginx -m 'nginx: master' }

The **every** key of each collector entry specifies the execution
interval, which you can specify in seconds (`[0-9]*s`), minutes
(`[0-9]*m`) or hours (`[0-9]*h`).

The **run** key specifies the collector to run.  Relative paths
are taken to be one of the standard Bolo collectors (see the
section _Available Collectors_).  Absolute paths allow the use of
collectors from other BOSH releases.

By default, you get the `linux` collector for free; it runs every
20s.  If you specify the **dbolo.collectors** property, however,
you will need to explicitly specify that configuration (as above).

### rrd

The `rrd` job runs the `bolo2rrd` subscriber, which listens to the
broadcast metrics from the core, and stores the data in RRD files
on disk, one per metric.

To wire up the rrd subscriber to the aggregator, specify the IP
address and port in the **bolo.rrd.subscription.address** and
**bolo.rrd.subscription.port** properties.  You normally only need
to specify the address, since the port defaults correctly.

The subscriber also submits data of its own, tracking things like
RRD operations and such.  For that, specify the
**bolo.rrd.submission.address** and **bolo.rrd.submission.port**
properties.

The default retention strategy (so-called Round-Robin Archives, or
RRAs), is to keep 8 days worth of minutely data.  You can change
this behavior via the **bolo.rrd.retention** parameter:

    properties:
      bolo:
        rrd:
          retention:
            - { at: 1m, for: 8d }

You can add more RRAs (retention periods) as well.  Here's a
retention policy that keeps minutely data for the past week, but
consolidates hourly for 90 days, and then daily for 10 years:

    properties:
      bolo:
        rrd:
          retention:
            - { at: 1m, for: 7d }
            - { at: 1h, for: 90d }
            - { at: 1d, for: 3650d }

Valid units are `m` (minutes), `h` (hours) or `d` (days).

You need the `rrd` job/template wherever you are going to run
`gnossis`, although that can be on a different VM from `bolo`
itself.

You may also want to look at the `rrdcached` job, that enables a
memory cache for coalescing RRD updates so that they get sent to
the underlying disk in batches, to improve I/O throughput:

    properties:
      bolo:
        rrd:
          cached: true   # bolo2rrd should use the cache...
        gnossis:
          cached: true   # let Gnossis control the cache too


### gnossis

Gnossis is a barebones web interface for viewing graphs of the
tracked measurements.  It ships with a set of default graph
definitions that should suffice for the builtin collectors (see
_Available Graphs_).

You can set the title of your Gnossis UI with the
**bolo.gnossis.name** property, so that you can tell multiple
deployments apart.


Available Collectors
--------------------

This BOSH release ships with the following collectors:

- **linux** - Gathers lots of systemwide information about a
  running Linux installation.
- **process** - Gathers process-specific information including
  memory, disk IO, CPU usage and open files.
- **files** - Monitor the state of files, including existence,
  sizes, number, etc.
- **httpd** - Gather interesting measurements from HTTP web
  servers like Apache or nginx.

### The `linux` Collector

    USAGE: linux [flags] [metrics]

    flags:
       -h, --help               Show this help screen
       -p, --prefix PREFIX      Use the given metric prefix
                                (FQDN is used by default)

    metrics:
       (no)mem           Memory utilization metrics
       (no)load          System Load Average metrics
       (no)cpu           CPU utilization (aggregate) metrics
       (no)procs         Process creation / context switching metrics
       (no)openfiles     Open File Descriptor metrics
       (no)mounts        Mountpoints and disk space usage metrics
       (no)paging        Virtual Memory paging statistics
       (no)disk          Disk I/O and utilization metrics
       (no)net           Network interface metrics

       By default, all metrics are collected.  You can suppress specific
       metric sets by prefixing its name with "no", without having to
       list out everything you want explicitly.

The `linux` collector gathers the following metrics:

#### Memory Utilization Metrics

| Type   | Name                   | Description |
| ------ | ---------------------- | ----------- |
| SAMPLE | $prefix:memory:total   | Total usable ram (i.e. physical ram minus a few reserved bits and the kernel binary code) |
| SAMPLE | $prefix:memory:used    | Memory in use by the kernel and running applications |
| SAMPLE | $prefix:memory:free    | Memory available for use by the kernel and running applicatons |
| SAMPLE | $prefix:memory:buffers | Relatively temporary storage for raw disk blocks shouldn't get tremendously large (20MB or so) |
| SAMPLE | $prefix:memory:cached  | In-memory cache for files read from the disk (the pagecache).  Doesn't include SwapCached |
| SAMPLE | $prefix:memory:slab    | In-kernel data structures cache |
| SAMPLE | $prefix:swap:total     | Total amount of swap space available |
| SAMPLE | $prefix:swap:cached    | Memory that once was swapped out, is swapped back in but still also is in the swapfile (if memory is needed it doesn't need to be swapped out AGAIN because it is already in the swapfile. This saves I/O) |
| SAMPLE | $prefix:swap:used      | How much of the total swap space is currently in use |
| SAMPLE | $prefix:swap:free      | Memory which has been evicted from RAM, and is temporarily on the disk |


#### System Load Average Metrics

| Type   | Name                  | Description |
| ------ | --------------------- | ----------- |
| SAMPLE | $prefix:load:1min     | One-minute rolling load average |
| SAMPLE | $prefix:load:5min     | Five-minute rolling load average |
| SAMPLE | $prefix:load:15min    | Fifteen-minute rolling load average |
| SAMPLE | $prefix:load:runnable | Number of runnable processes (i.e. those not blocked by I/O) |
| SAMPLE | $prefix:load:schedulable | Number of schedulable processes |


#### CPU Utilization (Aggregate) Metrics

| Type   | Name                   | Description |
| ------ | ---------------------- | ----------- |
| RATE   | $prefix:cpu:user       | Amount of time spent executing normal processes in user mode |
| RATE   | $prefix:cpu:nice       | Amount of time spent executing niced processes in user mode |
| RATE   | $prefix:cpu:system     | Amount of time spent executing processes in kernel mode |
| RATE   | $prefix:cpu:idle       | Amount of time spent doing nothing |
| RATE   | $prefix:cpu:iowait     | Amount of time spent executing waiting for I/O operations to complete |
| RATE   | $prefix:cpu:irq        | Amount of time spent executing servicing hardware interrupts |
| RATE   | $prefix:cpu:softirq    | Amount of time spent executing servicing software interrupts |
| RATE   | $prefix:cpu:steal      | Amount of time spent waiting involuntarily for the hypervisor to schedule us |
| RATE   | $prefix:cpu:guest      | Amount of time spent running a normal guest |
| RATE   | $prefix:cpu:guest-nice | Amount of time spent running a niced guest |
| RATE   | $prefix:ctxt:cswch-s   | Number of userspace/kernel context switches (in either direction), per second |
| RATE   | $prefix:ctxt:forks-s   | Number of new processes created per second, system-wide |
| SAMPLE | $prefix:load:cpus      | Number of visible processing cores (taking into account hyperthreading, if available) |


#### Process Creation / Context Switching Metrics


| Type   | Name                   | Description |
| ------ | ---------------------- | ----------- |
| SAMPLE | $prefix:procs:running  | Number of processes currently executing on a core |
| SAMPLE | $prefix:procs:sleeping | Number of processes sleeping (waiting to be run) |
| SAMPLE | $prefix:procs:blocked  | Number of processes blocked waiting on I/O |
| SAMPLE | $prefix:procs:zombies  | Number of zombie processes (dead-but-not-yet-waited-for) |
| SAMPLE | $prefix:procs:stopped  | Number of processes stopped by a SIGSTOP (i.e. a debugger) |
| SAMPLE | $prefix:procs:paging   | Number of processes in a _paging_ state (only relevant before Linux Kernel 2.6.0) |
| SAMPLE | $prefix:procs:unknown  | Number of processes in an unknown state |


#### Open File Descriptor Metrics

| Type   | Name                   | Description |
| ------ | ---------------------- | ----------- |
| SAMPLE | $prefix:openfiles:used | Number of open file descriptors in use, across all processes / threads |
| SAMPLE | $prefix:openfiles:free | Number of file descriptors available for use |
| SAMPLE | $prefix:openfiles:max | Maximum number of open file descriptors available for use |
|

#### Mountpoints and Disk Space Usage Metrics

**NOTE:** the metrics below will appear for each mounted block device, and
the `$MOUNT` placeholder will be replaced by the mountpoint itself (i.e.
`/var/vcap/store`).

| Type   | Name                           | Description |
| ------ | ------------------------------ | ----------- |
| SAMPLE | $prefix:df:$MOUNT:inodes.total | Total number of inodes on the underlying disk |
| SAMPLE | $prefix:df:$MOUNT:inodes.free  | Number of inodes available for general use |
| SAMPLE | $prefix:df:$MOUNT:inodes.rfree | Number of inodes available to the super user |
| SAMPLE | $prefix:df:$MOUNT:bytes.total  | Total size of the underlying disk, in bytes |
| SAMPLE | $prefix:df:$MOUNT:bytes.free   | Number of bytes available for general use |
| SAMPLE | $prefix:df:$MOUNT:bytes.rfree  | Number of bytes available to the super user |


#### Virtual Memory Paging Statistics

| Type | Name                     | Description |
| ---- | ------------------------ | ----------- |
| RATE | $prefix:vm:pgpgin        | Number of memory pages paged in |
| RATE | $prefix:vm:pgpgout       | Number of memory pages paged out |
| RATE | $prefix:vm:pswpin        | Number of memory pages paged in from swap space |
| RATE | $prefix:vm:pswpout       | Number of memory pages paged out to swap space |
| RATE | $prefix:vm:pgfree        | Number of "page free" events |
| RATE | $prefix:vm:pgfault       | Number of minor "page fault" events |
| RATE | $prefix:vm:pgmajfault    | Number of major "page fault" events |
| RATE | $prefix:vm:pgsteal       | How many times the kernel had to steal a page from the secondary page list because the primary was empty |
| RATE | $prefix:vm:pgscan.kswapd | Number of pages scanned by the `kswapd` daemon |
| RATE | $prefix:vm:pgscan.direct | Number of pages scanned directly by the kernel |


#### Disk I/O and Utilization Metrics

| Type | Name                          | Description |
| ---- | ----------------------------- | ----------- |
| RATE | $prefix:diskio:$DISK:rd-iops  | Number of read I/O operations completed |
| RATE | $prefix:diskio:$DISK:rd-miops | Number of reads that were merged of coalesced |
| RATE | $prefix:diskio:$DISK:rd-msec  | Time spent reading, in milliseconds |
| RATE | $prefix:diskio:$DISK:rd-bytes | Amount of data read, in bytes |
| RATE | $prefix:diskio:$DISK:wr-iops  | Number of write I/O operations completed |
| RATE | $prefix:diskio:$DISK:wr-miops | Number of writes that were merged or coalesced |
| RATE | $prefix:diskio:$DISK:wr-msec  | Time spent writing, in milliseconds |
| RATE | $prefix:diskio:$DISK:wr-bytes | Amount of data written, in bytes |


#### Network Interface Metrics

**NOTE:** the metrics below will appear for each network interface, and
the `$IFACE` placeholder will be replaced by the interface name (i.e. `lo`
for loopback, or `eth0`).  This may be difficult to understand on
container-based systems like the BOSH-lite Warden CPI.

| Type | Name                             | Description |
| ---- | -------------------------------- | ----------- |
| RATE | $prefix:net:$IFACE:rx.bytes      | Amount of data received, in bytes |
| RATE | $prefix:net:$IFACE:rx.packets    | Number of packets received |
| RATE | $prefix:net:$IFACE:rx.errors     | Number of erroneous packets received (invalid packet, bad checksum, etc.) |
| RATE | $prefix:net:$IFACE:rx.drops      | Number of received packets dropped (bad VLAN, wrong IP version, etc.) |
| RATE | $prefix:net:$IFACE:rx.overruns   | Number of packets received by the hardware, but dropped by the kernel |
| RATE | $prefix:net:$IFACE:rx.compressed | Number of compressed packets received |
| RATE | $prefix:net:$IFACE:rx.frames     | Number of packet framing errors |
| RATE | $prefix:net:$IFACE:rx.multicast  | Number of multicast packets received |
| RATE | $prefix:net:$IFACE:tx.bytes      | Amount of data sent, in bytes |
| RATE | $prefix:net:$IFACE:tx.packets    | Number of packets sent |
| RATE | $prefix:net:$IFACE:tx.errors     | Number of transmission errors detected by the driver |
| RATE | $prefix:net:$IFACE:tx.drops      | Number of transmitted packets dropped (wrong IP version, bad VLAN, etc.) |
| RATE | $prefix:net:$IFACE:tx.overruns   | Number of packets lost to outbound buffer overruns |
| RATE | $prefix:net:$IFACE:tx.compressed | Number of compressed packets sent |
| RATE | $prefix:net:$IFACE:tx.collisions | Number of collisions leading to retransmission |
| RATE | $prefix:net:$IFACE:tx.carrier    | Number of carrier (link layer) errors |


### The `process` Collector

    USAGE: process [options]

    options:
       -h, --help               Show this help screen
       -p, --prefix PREFIX      Use the given metric prefix
                                (FQDN is used by default)
       -n, --name NAME          Name of the process to look for
       -m, --match PATTERN      A PCRE regex for matching processes
       --children               Aggregate data from child processes

    note: this collector does not support systemd, and will only find
          processes that are children of init (PID 1).
          You will probably need to be root to run this collector.

The `process` collector gathers the following metrics:

| Type   | Name                          | Description |
| ------ | ----------------------------- | ----------- |
| SAMPLE | $prefix:proc:$PROC:openfiles  | Number of file descriptors in use by this process |
| SAMPLE | $prefix:proc:$PROC:processes  | Number of child processes (+1 for the main process) |
| SAMPLE | $prefix:proc:$PROC:threads    | Number of discretely schedulable threads.  Will match `processes` for single-threaded programs |
| RATE   | $prefix:proc:$PROC:utime      | Amount of CPU time spent in user mode |
| RATE   | $prefix:proc:$PROC:stime      | Amount of CPU time spent in kernel mode |
| RATE   | $prefix:proc:$PROC:iowait     | Amount of CPU time spent waiting for I/O to complete |
| RATE   | $prefix:proc:$PROC:guest_time | Amount of CPU time spent running a VCPU for a guest operating system (usually 0) |
| RATE   | $prefix:proc:$PROC:io_reads   | Number of read operations performed |
| RATE   | $prefix:proc:$PROC:io_all_rd  | Amount of data read, in bytes (includes disk, pipe and network traffic). |
| RATE   | $prefix:proc:$PROC:io_disk_rd | Amount of data read from the disk, in bytes |
| RATE   | $prefix:proc:$PROC:io_writes  | Number of write operations performed |
| RATE   | $prefix:proc:$PROC:io_all_wr  | Amount of data written, in bytes (includes disk, pipe and network traffic). |
| RATE   | $prefix:proc:$PROC:io_disk_wr | Amount of data written to the disk, in bytes |
| SAMPLE | $prefix:proc:$PROC:mem_libs   | How much memory is in use by dynamically loaded libraries |
| SAMPLE | $prefix:proc:$PROC:mem_anon   | How much memory is the process using in the form of anonymous memory mapped regions |
| SAMPLE | $prefix:proc:$PROC:mem_mmap   | How much memory is the process using in the form of shared (or private) memory mapped regions |
| SAMPLE | $prefix:proc:$PROC:mem_heap   | Size of the programs heap region (where dynamic allocation occurs) |
| SAMPLE | $prefix:proc:$PROC:mem_stack  | Size of the program stack (used by function activation records and local "automatic" variable allocation) |
| SAMPLE | $prefix:proc:$PROC:swp_libs   | How much swap space is taken up by
| SAMPLE | $prefix:proc:$PROC:swp_anon   | How much swap space is taken up by swapped-out anonymous memory mapped regions |
| SAMPLE | $prefix:proc:$PROC:swp_mmap   | How much swap space is taken up by swapped-out shared (or private) memory mapped regions |
| SAMPLE | $prefix:proc:$PROC:swp_heap   | How much swap space is taken up by swapped-out parts of the heap |
| SAMPLE | $prefix:proc:$PROC:swp_stack  | How much swap space is taken up by wapped-out parts of the stack |
| SAMPLE | $prefix:proc:$PROC:vmhwm      | Peak resident set size (RSS), or the "high water mark" of memory consumption |
| SAMPLE | $prefix:proc:$PROC:vmpeak     | Peak virtual memory footprint |
| SAMPLE | $prefix:proc:$PROC:vmrss      | Current resident size of the process |
| SAMPLE | $prefix:proc:$PROC:vmsize     | Current virtual memory footprint |

**NOTE:** in actual metrics, the `$PROC` placeholder will be replaced by the
`-n` argument to the `process` collector.  A good rule of thumb is to pass
the name of the program as `-n`.


### The `files` Collector

    USAGE: files <path> [options] -- <find(1) arguments>

    options:
       -h, -help                Show this help screen
       -p, -prefix PREFIX       Use the given metric prefix
                                (FQDN is used by default)
       -name NAME               Alternate name for files check
                                (Defaults to <path>)
       -debug                   Trace execution to standard error
       -track count             Track number of matching files (default)
       -track size              Track aggregated size of matching files
       -aggr (sum|min|max|avg)  Use the given summary function
                                (Only useful with `-track size`)

The `files` collector only ever returns a single metric per run.  Its
meaning depends on the `-track` and `-aggr` flags, and the name depends on
the `-name` flag.

| Type   | Name                 | Description |
| ------ | -------------------- | ----------- |
| SAMPLE | $prefix:files:$NAME  | Whatever was measured (`-track`) and how it was aggregated (`-aggr`) |

### The `httpd` Collector

    USAGE: httpd [options] URL

    options:
       -h, --help               Show this help screen
       -p, --prefix PREFIX      Use the given metric prefix
                                (FQDN is used by default)
       -t, --type TYPE          What type of HTTP server.
                                (Defaults to 'nginx')
                                Valid values: apache, nginx


Available Graphs
----------------

This BOSH release provides the following graphs, out of the box:

| Name                       | Collector   | Description |
| -------------------------- | ----------- | ----------- |
| data-flow                  | `linux`     | Shows how many samples are being tracked, per-aggregation-window |
| cpu                        | `linux`     | Aggregate CPU utilization, system-wide |
| load                       | `linux`     | Rolling load averages, 1-, 5- and 15-minute |
| memory                     | `linux`     | Memory usage, including buffers / cache /slab memory, system-wide |
| swap                       | `linux`     | Swap usage |
| paging                     | `linux`     | Virtual Memory Paging (unrelated to swap) |
| major-page-faults          | `linux`     | Major VMMU Page Faults |
| contextswitch              | `linux`     | Userspace / Kernel Mode context switches |
| fork_rate                  | `linux`     | Number of processes created, per unit time |
| processes                  | `linux`     | Number of processes total, in various states |
| openfiles                  | `linux`     | Number of open file descriptors, system-wide (includes maximum for perspective) |
| bolo-bogons                | -           | Tracks the number of Bogon PDUs (malformed) received per minute. (this is an internal metric) |
| bolo-throughput            | -           | Tracks the number of PDUs received per minute. (this is an internal metric) |
| proc-$NAME-cpu             | `process`   | Per-process CPU utilization |
| proc-$NAME-vmem            | `process`   | Per-process virtual memory utilization |
| proc-$NAME-io              | `process`   | Per-process I/O throughput (bytes read/written) |
| proc-$NAME-iorate          | `process`   | Per-process I/O rates (data per operation) |
| proc-$NAME-proceses        | `process`   | Number of child processes / threads |
| proc-$NAME-openfiles       | `process`   | Per-process open file descriptor usage |
| df-$MOUNT-bytes            | `linux`     | Per-mountpoint disk usage (capacity) |
| df-$MOUNT-inodes           | `linux`     | Per-mountpoint disk usage (file counts) |
| $DEV-disk-io               | `linux`     | Per-device disk I/O (bytes) |
| $DEV-disk-iops             | `linux`     | Per-device disk I/O (operations) |
| $DEV-disk-await            | `linux`     | Per-device average wait time before being serviced by hardware |
| $IFACE-inet-packets        | `linux`     | Per-interface packets sent/received |
| $IFACE-inet-errors         | `linux`     | Per-interface errors (rx/tx) |
| $IFACE-inet-traffic        | `linux`     | Per-interface throughput (bytes) sent/received |
| nginx-connections          | `httpd`     | - |
| nginx-throughput           | `httpd`     | - |
| nginx-conection-issues     | `httpd`     | - |
| nginx-conection-reuse      | `httpd`     | - |
| pg-queries                 | `postgres`  | - |
| pg-io                      | `postgres`  | - |
| pg-table-states            | `postgres`  | - |
| pg-$DB-dbsize              | `postgres`  | - |
| pg-$DB-transactions        | `postgres`  | - |
| pg-$DB-backends            | `postgres`  | - |
| rrdcached-disk-writes      | `rrdcached` | - |
| rrdcached-flush-requests   | `rrdcached` | - |
| rrdcached-updates-requests | `rrdcached` | - |
| rrdcached-journal-size     | `rrdcached` | - |
| rrdcached-journal-rotates  | `rrdcached` | - |
| rrdcached-rrds-cached      | `rrdcached` | - |
| rrdcached-tree-depth       | `rrdcached` | - |
| rrdcached-queue-length     | `rrdcached` | - |




[bolo]:    http://bolo.niftylogic.com
[plugins]: https://github.com/bolo/bolo-collectors
[tpl]:     https://github.com/bolo/bolo-deployment
[genesis]: https://github.com/starkandwayne/genesis

[screen1]: https://raw.githubusercontent.com/cloudfoundry-community/bolo-boshrelease/master/doc/gnossis.png
