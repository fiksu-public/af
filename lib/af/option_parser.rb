module Af::OptionParser
  class MisconfiguredOptionError < ArgumentError; end

  def self.included(base)
    base.extend(UI)
  end

  # used by application code to note an error and exit
  def opt_error(text)
    puts text
    Helper.new.help(usage)
    exit 1
  end

  # Returns the current version of the application.
  # *Must be overridden in a subclass.*
  def application_version
    return "#{self.class.name}: unknown application version"
  end

  # Returns a string detailing application usage.
  def usage
    return "rails runner #{self.class.name}.run [OPTIONS]"
  end

  # Update options for the provided long switch option name.
  #  just a helper to UI method "opt"
  def opt_update(long_name, *extra_stuff, &b)
    self.class.opt(long_name, *extra_stuff, &b)
  end

  # Collect and process all of the switches (values) on the command
  # line, as previously configured.
  def process_command_line_options
    CommandLineOptionParser.new(self, usage).process
  end
end
