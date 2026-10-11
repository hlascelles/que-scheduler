# typed: true

# activejob is only bundled in the appraisals, so tapioca cannot generate its RBI.

class ActiveJob::Base
  sig { params(options: T.anything).returns(ActiveJob::ConfiguredJob) }
  def self.set(options = {}); end
end

class ActiveJob::ConfiguredJob
  sig { params(args: T.anything, kwargs: T.anything).returns(T.nilable(T.any(ActiveJob::Base, FalseClass))) }
  def perform_later(*args, **kwargs); end
end
