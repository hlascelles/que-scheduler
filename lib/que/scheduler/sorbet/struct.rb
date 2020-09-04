# frozen_string_literal: true

require "sorbet-runtime"

module Que
  module Scheduler
    module Sorbet
      class Struct < T::InexactStruct
        def serialize(strict = nil)
          super.transform_keys!(&:to_sym)
        end
      end
    end
  end
end
