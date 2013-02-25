module Af::OptionParser
  # Utility base class for executing Ruby scripts on the command line. Provides
  # methods to define, gather, parse and cast command line options. Options are
  # stored as class instance variables.
  module Dsl
    ### Class methods ###

    # Declare a command line options group.
    #
    # *Arguments*
    #   * group_name - name of the group
    #   * extra_stuff (Hash)
    #     * :title - title of the group (optional)
    #     * :description -
    #     * :priority -
    #
    def opt_group(group_name, *extra_stuff)
      title = nil
      priority = nil
      description = nil
      hidden = nil

      maybe_title = extra_stuff.shift
      if maybe_title.is_a? String
        title = maybe_title
      else
        extra_stuff.shift(maybe_title)
      end

      maybe_hash = extra_stuff[-1]
      if maybe_hash.is_a? Hash
        title = maybe_hash[:title] if maybe_hash.has_key? :title
        priority = maybe_hash[:priority] if maybe_hash.has_key? :priority
        description = maybe_hash[:description] if maybe_hash.has_key? :description
        hidden = maybe_hash[:hidden] if maybe_hash.has_key? :hidden
      end

      OptionGroup.factory(group_name, title, priority, description, hidden)
    end

    # Declare a command line option switch.
    #
    # *Arguments*
    #   * long_name - long version of the switch
    #   * extra_stuff - hash with the following possible keys:
    #     :var => <instance variable name>
    #     :default => <default value>
    #     :no_accessor => <false to skip setting accessor>
    #     :set => <???>
    #     :type => <type to cast option value??>
    #     :method => <lambda or proc to process value??>
    #     :hidden => <???>
    #     :group => <name of group?>
    #     :priority => <integer??>
    #     :argument => <arg type: required, none, optional>
    #     :choices => <???>
    #     :environment_variable => <???>
    #     :argument_note => <???>
    #
    # if block is passed without long_name, then block is simply yeilded to
    #  (this is used to group options visually)
    # if block is otherwised passed it is called with OPTION,ARGUMENT_VALUE when seen on the command line
    #
    def opt(long_name = nil, *extra_stuff, &b)
      if b && long_name.nil?
        yield
        return
      end

      if long_name.nil?
        raise MisconfiguredOptionError.new("no name given for option")
      end

      # Create hash for processed options.
      extras = extra_stuff[-1]
      if extras.is_a? Hash
        # if extras is a Hash, then the rest of extra_stuff is an array, which
        # is expected to be:
        #   NOTE (String)
        # or:
        #   TYPE (Symbol)
        # or:
        #   REQUIREMENT (Symbol)
        extra_stuff.pop
      else
        extras = {}
      end

      # Iterate through and process all of the other arguments.
      while extra_stuff.length > 0
        extra = extra_stuff.shift
        if extra.is_a?(Symbol)
          if [:required, :optional, :none].include?(extra)
            extras[:argument] = extra
          elsif Option.all_option_types.include?(extra)
            extras[:type] = extra
          else
            raise MisconfiguredOptionError.new("#{long_name}: extra options: #{extra.inspect} are not understood")
          end
        elsif extra.is_a?(String)
          extras[:note] = extra
        else
          raise MisconfiguredOptionError.new("#{long_name}: extra options: #{extra.inspect} are not understood")
        end
      end

      # Ensure long name is in the proper string format.
      long_name = long_name.to_s
      unless long_name[0..1] == "--"
        long_name = "--#{long_name.gsub(/_/,'-')}"
      end

      unless extras[:type]
        # If we are not just setting a switch, then we can use the default value
        # and assume this switch has a required argument.
        if extras[:default].present? && extras[:set].nil?
          type = OptionType.find_by_value(extras[:default]).try(:short_name)
          extras[:type] = type unless type.nil?
        end
      end

      # Determine argument requirement type.
      argument = if extras[:argument] == :required
                   ::Af::OptionParser::GetOptions::REQUIRED_ARGUMENT
                 elsif extras[:argument] == :none
                   ::Af::OptionParser::GetOptions::NO_ARGUMENT
                 elsif extras[:argument] == :optional
                   ::Af::OptionParser::GetOptions::OPTIONAL_ARGUMENT
                 elsif extras[:argument] == nil
                   if extras[:type]
                     ::Af::OptionParser::GetOptions::REQUIRED_ARGUMENT
                   else
                     ::Af::OptionParser::GetOptions::NO_ARGUMENT
                   end
                 else
                   extras[:argument]
                 end

      # Determine argument type if it is not explictly given
      unless extras[:type]
        if extras[:set]
          type = OptionType.find_by_value(extras[:set]).try(:short_name)
          extras[:type] = type unless type.nil?
        end
      end

      # Add the switch to the store, along with all of it's options.
      option_hash = {
        :requirements => argument
      }
      option_hash[:note] = extras[:note] if extras[:note]
      if extras[:short]
        short = extras[:short].to_s
        unless short[0] == '-'
          short = "-#{short}"
        end
        option_hash[:short] = short
      end
      option_hash[:argument_note] = extras[:argument_note] if extras[:argument_note]
      option_hash[:environment_variable] = extras[:environment_variable] if extras[:environment_variable]
      option_hash[:environment_variable] = extras[:env] if extras[:env]
      option_hash[:default_value] = extras[:default] if extras[:default]
      if extras[:type]
        option_hash[:option_type] = OptionType.find_by_short_name(extras[:type])
        raise MisconfiguredOptionError.new("#{long_name}: option type #{extras[:type].inspect} is not recognized. (valid option types: #{OptionType.valid_option_type_names.join(', ')})") unless option_hash[:option_type]
      end
      option_hash[:target_variable] = extras[:var] if extras[:var]
      option_hash[:value_to_set_target_variable] = extras[:set] if extras[:set]
      option_hash[:evaluation_method] = extras[:method] if extras[:method]
      option_hash[:evaluation_method] = b if b
      option_hash[:option_group_name] = extras[:group] if extras[:group].present?
      option_hash[:hidden] = extras[:hidden] if extras[:hidden].present?
      option_hash[:choices] = extras[:choices] if extras[:choices].present?
      option_hash[:do_not_create_accessor] = extras[:no_accessor] if extras[:no_accessor].present?
      option_hash[:long_name] = long_name

      Option.factory(option_hash[:long_name], option_hash[:short_name], option_hash[:option_type], option_hash[:requirements],
                     option_hash[:argument_note], option_hash[:note], option_hash[:environment_variable], option_hash[:default_value],
                     option_hash[:target_variable], option_hash[:value_to_set_target_variable], option_hash[:evaluation_method],
                     option_hash[:option_group_name], option_hash[:hidden], option_hash[:choices], option_hash[:do_not_create_accessor])
    end

    # Convert or process the provided argument value based on the provided type.
    #
    # *Arguments*
    #   * argument - the value to be processed
    #   * type_name - the argument's type
    #   * option_name - name of argument option (only used for logging)
    #   * command_line_options - options hash for the given option_name
    def self.evaluate_argument_for_type(argument, type_name, option_name, command_line_option)
      argument_availability = command_line_option[:argument]
      choices = command_line_option[:choices]

      if type_name == :int
        return argument.to_i
      elsif type_name == :float
        return argument.to_f
      elsif type_name == :string
        return argument.to_s
      elsif type_name == :uri
        return URI.parse(argument)
      elsif type_name == :date
        return Time.zone.parse(argument).to_date
      elsif type_name == :time
        return Time.zone.parse(argument)
      elsif type_name == :choice
        choice = argument.to_sym
        unless choices.blank?
          unless choices.include? choice
            puts "#{self.name}: #{option_name}: invalid choice '#{choice}' not in list of choices: #{choices.map(&:to_s).join(', ')}"
            exit 0
          end
        end
        return choice
      elsif type_name == :hash
        return Hash[argument.split(',').map{|a| a.split('=')}]
      elsif type_name == :ints
        return argument.split(',').map(&:to_i)
      elsif type_name == :floats
        return argument.split(',').map(&:to_f)
      elsif type_name == :strings
        return argument.split(',').map(&:to_s)
      elsif type_name == :uris
        return argument.split(',').map{|a| URI.parse(a)}
      elsif type_name == :dates
        return argument.split(',').map{|a| Time.zone.parse(a).to_date}
      elsif type_name == :times
        return argument.split(',').map{|a| Time.zone.parse(a)}
      elsif type_name == :choices
        choice_list = argument.split(',').map(&:to_sym)
        unless choices.blank?
          choice_list.each do |choice|
            unless choices.include? choice
              puts "#{self.name}: #{option_name}: invalid choice '#{choice}' not in list of choices: #{choices.map(&:to_s).join(', ')}"
              exit 0
            end
          end
        end
        return choice_list
      else
        if argument_availability == ::Af::OptionParser::GetOptions::REQUIRED_ARGUMENT
          argument = true
        end
        return argument
      end
    end
  end
end
