module Af::OptionParser
  class MisconfiguredOptionError < ArgumentError; end

  def self.included(base)
    base.extend(UI)
  end

  # used by application code to note an error and exit
  def opt_error(text)
    puts text
    help(usage)
    exit 1
  end

  # Returns the current version of the application.
  # *Must be overridden in a subclass.*
  def application_version
    return "#{self.class.name}: unknown application version"
  end

  # Returns a string detailing application usage.
  def usage
    return @usage
  end

  # Update options for the provided long switch option name.
  #  *Arguments*
  #   * long_name - string name of switch
  #   * updates - hash of chnages to option configuration
  def update_opts(long_name, updates)
    long_name = long_name.to_s
    # Convert prefix underscores to dashes.
    unless long_name[0..1] == "--"
      long_name = "--#{long_name.gsub(/_/,'-')}"
    end
    (all_command_line_options_stores[long_name] || {}).merge!(updates)
  end

  # Collect and process all of the switches (values) on the command
  # line, as previously configured.
  #
  # TODO AK: As far as I can tell, the "options" hash argument is never
  # used.  Perhaps it can be removed?
  def command_line_options(options = {}, usage = nil)
    # Set usage if provided, otherwise set to default.
    if usage.nil?
      @usage = "rails runner #{self.class.name}.run [OPTIONS]"
    else
      @usage = usage
    end

    # Iterate through all options in the class heirachy.
    # Create instance variables and accessor methods for each.
    all_command_line_options_stores.each do |long_name,options|
      unless options[:var]
        var_name = long_name[2..-1].gsub(/-/, '_').gsub(/[^0-9a-zA-Z]/, '_')
        options[:var] = var_name
      end
      if options[:var]
        if options[:default].present? || !self.instance_variable_defined?("@#{options[:var]}".to_sym)
          self.instance_variable_set("@#{options[:var]}".to_sym, options[:default])
        end
        unless options[:no_accessor]
          eval("class << self; attr_accessor :#{options[:var]}; end")
        end
      end
    end

    # Fetch the actual switches (and values) from the command line.
    get_options = ::Af::GetOptions.new(all_command_line_options_stores)

    # Iterate through the command line options. Print and exit if the switch
    # is invalid, help or app version.  Otherwise, process and handle.
    get_options.each do |option,argument|
      if option == '--?'
        help(usage)
        exit 0
      elsif option == '--??'
        help(usage, true)
        exit 0
      elsif option == '--application-version'
        puts application_version
        exit 0
      else
        command_line_option = all_command_line_options_stores[option]
        if command_line_option.nil?
          puts "unknown option: #{option}"
          help(usage)
          exit 0
        elsif command_line_option.is_a?(Hash)
          # Try to determine argument type and cast it.
          argument = command_line_option[:set] || argument
          type_name = OptionType.find_by_value(command_line_option[:set]).try(:short_name)
          type_name = command_line_option[:type] unless command_line_option[:type].blank?
          type_name = :string if type_name.nil? && command_line_option[:method].nil?
          argument_value = self.class.evaluate_argument_for_type(argument, type_name, option, command_line_option)
          # Argument converted, so call with proc and/or assign to instance variable.
          if command_line_option[:method]
            argument_value = command_line_option[:method].call(option, argument_value)
          end
          if command_line_option[:var]
            self.instance_variable_set("@#{command_line_option[:var]}".to_sym, argument_value)
          end
        end
        # TODO AK: This seems to only be declared in the subclass Application,
        # which seems super dangerous.  Maybe there should at least be an empty
        # emthod declaration in this class that raises a NotImplementedError?
        option_handler(option, argument)
      end
    end
  end

end
