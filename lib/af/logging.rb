module Af::Logging
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
  end

  def logging_configurator
    return Configurator.singleton
  end
end
