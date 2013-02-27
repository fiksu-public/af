module Af::OptionParser
  module Interface
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
      # Iterate through all options in the class heirachy.
      # Create instance variables and accessor methods for each.

      options = Option.all_options.values
      options.each(&:instantiate_target_variable)

      # Fetch the actual switches (and values) from the command line.
      get_options = GetOptions.new(options)

      # Iterate through the command line options. Print and exit if the switch
      # is invalid, help or app version.  Otherwise, process and handle.
      get_options.each do |long_name,argument|
        option = Option.find(long_name)
        # XXX are these three lines needed?
        if option.nil?
          opt_error "unknown option: #{long_name}"
        end

        option.evaluate_and_set_target(argument)
      end
    end
  end
end
