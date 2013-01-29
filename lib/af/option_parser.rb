module Af::OptionParser
  class MisconfiguredOptionError < ArgumentError; end

  def self.included(base)
    base.include(Interface)
    base.extend(Dsl)
  end
end
