module Af::OptionParser
  class CommandLineOptionParser
    def initialize(application, usage)
      @application = application
      @usage = usage
    end

    def process
      # Iterate through all options in the class heirachy.
      # Create instance variables and accessor methods for each.
      Option.all_options.each do |long_name,option|
        unless option.target_variable
          var_name = long_name[2..-1].gsub(/-/, '_').gsub(/[^0-9a-zA-Z]/, '_')
          option.target_variable = var_name
        end
        if option.target_variable
          if option.default_value.present? || !self.instance_variable_defined?("@#{option.target_variable}".to_sym)
            self.instance_variable_set("@#{option.target_variable}".to_sym, option.default_value)
          end
          unless option.do_not_create_accessor
            eval("class << self; attr_accessor :#{option.target_variable}; end")
          end
        end
      end

      # Fetch the actual switches (and values) from the command line.
      get_options = GetOptions.new(Option.all_options)

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

        option.evaluate(argument)

        # Try to determine argument type and cast it.
        argument = option.value_to_set_target_variable || argument
        type_name = OptionType.find_by_value(option.value_to_set_target_variable).try(:short_name)
        type_name = option[:type] unless option[:type].blank?
        type_name = :string if type_name.nil? && option[:method].nil?
        argument_value = self.class.evaluate_argument_for_type(argument, type_name, long_name, option)
        # Argument converted, so call with proc and/or assign to instance variable.
        if option[:method]
          argument_value = option[:method].call(long_name, argument_value)
        end
        if option[:var]
          self.instance_variable_set("@#{option[:var]}".to_sym, argument_value)
        end
      end
    end

    def help(show_hidden = false)
      Helper.new.help(usage, show_hidden)
    end
  end
end
