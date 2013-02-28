module Af::OptionParser
  module Interface
    # used by application code to note an error and exit
    def opt_error(text)
      puts text
      Helper.new.help(usage)
      exit 1
    end

    # Returns a string detailing application usage.
    def usage
      return "USAGE: rails runner #{self.class.name}.run [OPTIONS]"
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
      begin
        get_options.each do |long_name,argument|
          option = Option.find(long_name)

          option.evaluate_and_set_target(argument)
        end
      rescue GetoptLong::InvalidOption, OptionParserError => e
        opt_error e.message
      end
    end
  end
end
