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

    # Update Options for the provided long switch option name.
    # Just a helper to UI method "opt"
    def opt(long_name, *extra_stuff, &b)
      self.class.opt(long_name, *extra_stuff, &b)
    end

    # Update OptionGroups for the provided group option name.
    # Just a helper to UI method "opt_group"
    def opt_group(group_name, *extra_stuff, &b)
      self.class.opt_group(group_name, *extra_stuff, &b)
    end

    # Update OptionGroups for the provided group option name.
    # Just a helper to UI method "opt_check"
    def opt_check(var_name, *extra_stuff, &b)
      self.class.opt_check(var_name, *extra_stuff, &b)
    end

    # Update OptionGroups for the provided group option name.
    # Just a helper to UI method "opt_select"
    def opt_select(var_name, *extra_stuff, &b)
      self.class.opt_select(var_name, *extra_stuff, &b)
    end

    # Collect and process all of the switches (values) on the command
    # line, as previously configured.
    def process_command_line_options(af_option_interests)
      # Iterate through all options in the class heirachy.
      # Create instance variables and accessor methods for each.

      option_finder = OptionFinder.new(af_option_interests)

      options = option_finder.all_options
      options.each(&:instantiate_target_variable)

      # Fetch the actual switches (and values) from the command line.
      get_options = GetOptions.new(options)

      # Iterate through the command line options. Print and exit if the switch
      # is invalid, help or app version.  Otherwise, process and handle.
      begin
        get_options.each do |long_name, argument|
          option_finder.find_option(long_name).evaluate_and_set_target(argument)
        end
      rescue GetoptLong::Error, Error => e
        opt_error e.message
      end
    end

  end
end
