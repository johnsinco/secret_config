require "date"
require "socket"
require "securerandom"
# * SecretConfig Interpolations
#
# Expanding values inline for date, time, hostname, pid and random values.
#   %{date}           # Current date in the format of "%Y%m%d" (CCYYMMDD)
#   %{date:format}    # Current date in the supplied format. See strftime
#   %{time}           # Current date and time down to ms in the format of "%Y%m%d%Y%H%M%S%L" (CCYYMMDDHHMMSSmmm)
#   %{time:format}    # Current date and time in the supplied format. See strftime
#   %{env:name}       # Extract value from the named environment value.
#   %{hostname}       # Full name of this host.
#   %{hostname:short} # Short name of this host. Everything up to the first period.
#   %{pid}            # Process Id for this process.
#   %{random}         # URL safe Random 32 byte value.
#   %{random:size}    # URL safe Random value of `size` bytes.
#
# Retrieve values elsewhere in the registry.
# Paths can be relative to the current root, or absolute paths outside the current root.
#   %{fetch:key}      # Fetches a single value from a relative or absolute path
#   %{include:path}   # Fetches a path of keys and values
module SecretConfig
  class SettingInterpolator < StringInterpolator
    def date(format = "%Y%m%d")
      Date.today.strftime(format)
    end

    def time(format = "%Y%m%d%H%M%S%L")
      Time.now.strftime(format)
    end

    def env(name)
      ENV[name]
    end

    def hostname(format = nil)
      name = Socket.gethostname
      name = name.split(".")[0] if format == "short"
      name
    end

    def pid
      $$
    end

    def random(size = 32)
      SecureRandom.urlsafe_base64(size)
    end

    # def fetch(key)
    #  SecretConfig[key]
    # end
    #
    # def include(path)
    #
    # end
  end
end
