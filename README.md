# time.sh
Shell script helper to measure execution times

## Example
Say our script does three main tasks: "FOO", "BAR 1" and "BAR 2", and we want
to measure how long each of them takes individually and as percentage of
the overall duration:
```sh
#!/bin/sh

# tell time_switch_to to print nothing (see below)
TIME_PRINT=0

# load and initialize time.sh
. path/to/time.sh

# start timing task FOO
time_switch_to FOO

# some lengthy task FOO

# FOO is done, "BAR 2" starts
time_switch_to "BAR 2"
# ...

time_switch_to "BAR 3"
# ...

# consider the last task done and print a summary
time_finish

# measurements are now reset and we can start a new group
```
The above might produce the following output:
```
-----
2002 ms, 17 ms/measure, Linux/dash
-----
1200 ms  60 %  BAR 2
 501 ms  25 %  BAR 3
 301 ms  15 %  FOO
-----
```

The summary sorts the meaured durations and adds the total, and also prints an
assessment of the measurement overhead (17 ms) which is the duration it takes
`time_switch_to` itself to run. This fixed number (per run) is already
subtracted from each of the measurements at the summary.

The overhead is mostly affected by how long it takes to read a timestamp, and
depends on the command used for that. It's calculated automatically on init
by running the timestamp command few times and averaging it.

The timestamp command is also determined at runtime: if the system `date`
command supports nanosec, then this is used, else it tries to use python,
else perl, and else falls back to using the `date` command with seconds
resolution.

### Important
`time.sh` is not a profiler. It's a simple helper. Specifically:
- It won't accumulate the values if a task FOO is switched to more than once.
- All timing calls should be made from the same shell context. `time.sh` stores
  intermediate values in environment variables, therefore values will be lost
  if some calls are made from subshells and some are not.
- It's not suitable for micro benchmarks of tasks which complete very quickly,
  because `task_switch_to` itself has a non negligible overhead. In general,
  a measurement can be considered reasonably accurate if it's at least twice
  longer than the overhead - which is printed at the summary.

### Configuration
`time.sh` can be customized via environment variables. If used, `TIME_CMD` and
`TIME_COMP` should be set _before_ `time.sh` is loaded, and the rest can be
set/changed at any time:

- `TIME_PRINT` (default 3) controls what `time_switch_to` prints: 1 for
  printing only the task which starts now, 2 to print only the task which just
  finished (and its duration), 3 to print both, and 0 to print nothing.
- `TIME_CMD` a command to execute which prints a timestamp in ms. If empty then
  `time.sh` tries several commands on init and sets it automaticaly.
- `TIME_COMP` compensation in ms for each measurement = the overhead of
  `time_switch_to`. You should leave this empty to let `time.sh` assess it
  automatically, or override it with a custom value (which will be subtracted
  from each measurement).
- `TIME_TITLE` (default empty) arbitrary string which will be incorporated into
  the summary which `time_finish` prints.

If you prefer to print your own summary instead of the default, then insead of
calling `time_finish` call `time_switch_to --`, after which `$time_total` will
have the value of the total ms measured, and `$time_details` will have one line
for each task with the measured ms and task name.

In addition to the global variables and functions mentioned above, there are
few more where each begins with `_tsh_`.