module Af::OptionParser
  class CommandLineOptionParser
    def initialize(application, usage)
      @application = application
      @usage = usage
    end

    def process
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
        if option.nil?
          puts "unknown option: #{long_name}"
          help
          exit 1
        end

        if long_name == '--?'
          help
          exit 0
        elsif long_name == '--??'
          help(true)
          exit 0
        elsif long_name == '--application-version'
          puts application_version
          exit 0
        end

        option.evaluate_and_set_target(argument)
      end
    end

    def help(show_hidden = false)
      Helper.new.help(@usage, show_hidden)
    end
  end
end
