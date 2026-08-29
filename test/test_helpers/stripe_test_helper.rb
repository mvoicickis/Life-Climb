# frozen_string_literal: true

module StripeTestHelpers
  def with_singleton_stubs(stubs)
    originals = {}

    stubs.each do |object, methods|
      methods.each do |method_name, implementation|
        originals[[ object, method_name ]] = object.method(method_name)
        object.define_singleton_method(method_name, &implementation)
      end
    end

    yield
  ensure
    originals.each do |(object, method_name), original|
      object.define_singleton_method(method_name, original)
    end
  end
end

ActiveSupport::TestCase.include StripeTestHelpers
