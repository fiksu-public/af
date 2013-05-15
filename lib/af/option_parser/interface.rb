module Af::OptionParser
  module Interface
    # used by application code to note an error and exit
    def opt_error(text)
      self.class.opt_error(text)
    end

    # Returns a string detailing application usage.
    def usage
      return self.class.usage
    end

    # Update options for the provided long switch option name.
    #  just a helper to UI method "opt"
    def opt(long_name, *extra_stuff, &b)
      self.class.opt(long_name, *extra_stuff, &b)
    end

    # Update option_groups for the provided group option name.
    #  just a helper to UI method "opt_group"
    def opt_group(group_name, *extra_stuff, &b)
      self.class.opt_group(group_name, *extra_stuff, &b)
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
      begin
        get_options.each do |long_name,argument|
          option = Option.find(long_name)

          option.evaluate_and_set_target(argument)
        end
      rescue GetoptLong::Error, Error => e
        opt_error e.message
      end
    end
  end
end
