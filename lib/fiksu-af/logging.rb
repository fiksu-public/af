module Af::Logging
  def self.included(base)
    Configurator.singleton
  end

  def logger(logger_name = :default)
    return Configurator.singleton.logger(logger_name)
  end

  def logging_configurator
    return Configurator.singleton
  end
end
