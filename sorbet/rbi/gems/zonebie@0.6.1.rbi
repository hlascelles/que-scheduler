# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `zonebie` gem.
# Please instead update this file by running `tapioca generate`.

# typed: true

module Zonebie
  class << self
    def add_backend(backend); end
    def backend; end
    def backend=(backend); end
    def quiet; end
    def quiet=(_arg0); end
    def random_timezone; end
    def set_random_timezone; end
  end
end

module Zonebie::Backends
end

class Zonebie::Backends::ActiveSupport
  class << self
    def name; end
    def usable?; end
    def zone=(zone); end
    def zones; end
  end
end

class Zonebie::Backends::TZInfo
  class << self
    def name; end
    def usable?; end
    def zone=(zone); end
    def zones; end
  end
end

Zonebie::VERSION = T.let(T.unsafe(nil), String)