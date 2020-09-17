# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require "sorbet-struct-comparable"

module Que
  module Scheduler
    module Sorbet
      class Struct < T::InexactStruct
        include T::Struct::ActsAsComparable

        def to_h
          serialize.transform_keys!(&:to_sym)
        end
      end
    end
  end
end
