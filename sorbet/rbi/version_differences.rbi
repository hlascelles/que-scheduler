# This is only in Que 1.0, so we have to declare it here so type checks for other Que versions work
Que::DEFAULT_QUEUE = T.let(String)
module Que
  class << self
    def run_synchronously(); end
  end
end

# ActiveJob isn't always included in some tests (and by default), so define it here
class ::ActiveJob::Base; end
