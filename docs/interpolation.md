---
layout: default
---

## String Interpolation

Values supplied for config settings can be replaced inline with date, time, hostname, pid and random values.

For example to include the `hostname` in the log file name setting:

~~~yaml
development:
  logger:
    level:     info
    file_name: /var/log/my_application_${hostname}.log
~~~

Available interpolations:

* ${date}
    * Current date in the format of "%Y%m%d" (CCYYMMDD)
* ${date:format}
    * Current date in the supplied format. See strftime
* ${time}
    * Current date and time down to ms in the format of "%Y%m%d%Y%H%M%S%L" (CCYYMMDDHHMMSSmmm)
* ${time:format}
    * Current date and time in the supplied format. See strftime
* ${env:name}
    * Extract value from the named environment variable.
* ${hostname}
    * Full name of this host.
* ${hostname:short}
    * Short name of this host. Everything up to the first period.
* ${pid}
    * Process Id for this process.
* ${random}
    * URL safe Random 32 byte value.
* ${random:size}
    * URL safe Random value of `size` bytes.

#### Notes:

* To prevent interpolation use $${...}
* $$ is not touched, only ${...} is searched for.
* Since these interpolations are only evaluated at load time and
  every time the registry is refreshed there is no runtime overhead when keys are fetched.
