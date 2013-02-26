module Af::OptionParser
  class CommandLineOptionParser
    def initialize(application, usage)
      @application = application
      @usage = usage
    end

    def process
      # Iterate through all options in the class heirachy.
      # Create instance variables and accessor methods for each.

      options = Option.all_options
      options.each do |long_name,option|
        if option.target_variable
          if option.default_value.present? || !@application.instance_variable_defined?("@#{option.target_variable}".to_sym)
            @application.instance_variable_set("@#{option.target_variable}".to_sym, option.default_value)
          end
          unless option.do_not_create_accessor
            @application.class.class_eval "attr_accessor :#{option.target_variable}"
          end
        end
      end

      # Fetch the actual switches (and values) from the command line.
      get_options = GetOptions.new(options)

      # Iterate through the command line options. Print and exit if the switch
      # is invalid, help or app version.  Otherwise, process and handle.
      get_options.each do |long_name,argument|
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

        option = Option.find(long_name)

        if option.nil?
          puts "unknown option: #{long_name}"
          help
          exit 1
        end

        argument_value = option.evaluate(argument)
        if option.target_variable
          @application.instance_variable_set("@#{option.target_variable}".to_sym, argument_value)
        end
      end
    end

    def help(show_hidden = false)
      Helper.new.help(@usage, show_hidden)
    end
  end
end
