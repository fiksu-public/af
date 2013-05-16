module Af::OptionParser
  # Utility base class for executing Ruby scripts on the command line. Provides
  # methods to define, gather, parse and cast command line options. Options are
  # stored as class instance variables.
  module Dsl
    ### Class methods ###

    @@opt_group_stack = []
    def opt_get_top_of_stack
      return (@@opt_group_stack[-1] || {}).clone
    end

    # Declare a command line options group.
    #
    # *Arguments*
    #   * group_name - name of the group
    #   * extra_stuff (Hash)
    #     * :title - display title of the group (optional)
    #     * :description - details about group
    #     * :priority - order to show groups in help --?
    #     * :hidden - true if this group's options should only be seen with --?
    #     * :disabled - (default: false)
    #     *  anything else in this hash can be passed to yield block as defaults for other opt/opt_group invocations
    #   * yeilds to block if given with extra_stuff in a global space that opt/opt_group calls use as defaults

    def opt_group(group_name, *extra_stuff)
      # grab information from our yied scope
      factory_hash = opt_get_top_of_stack

      # update factory_hash with information in array area first (left parameters of the dsl)
      maybe_title = extra_stuff.shift
      if maybe_title.is_a? String
        factory_hash[:title] = maybe_title
      else
        extra_stuff.unshift(maybe_title)
      end

      # then fold in the hash
      maybe_hash = extra_stuff[-1] || {}
      if maybe_hash.is_a? Hash
        factory_hash.merge! maybe_hash
      end

      OptionGroup.factory(group_name, factory_hash)
      # if a block is given, then let the yeilded block 
      # have access to our scoped hash.
      if block_given?
        begin
          @@opt_group_stack.push factory_hash.merge({:group => group_name})
          yield
        ensure
          @@opt_group_stack.pop
        end
      end
    end

    # Declare a command line option switch.
    #
    # *Arguments*
    #   * long_name - long version of the switch
    #   * extra_stuff - hash with the following possible keys:
    #     :type - (:option_type) the OptionType
    #     :argument - (:requirements) is a parameter value requied (valid values: :required, :optional, :none)
    #     :short - (:short_name) the single letter used for this option (i.e., :e = '-e')
    #     :argument_note - used in --? as the typename of the parameter (e.g. ENGLISH_WORD)
    #     :note - used in --? as the help text
    #     :environment_variable - the name of the environment variable associated with this switch
    #     :default - (:default_value) the default value of the parameter
    #     :method - (:evaluation_method) called to evaluate argument: lambda{|argument,option| ... }
    #     :group - (:option_group_name) name of group
    #     :hidden - should option only be shown in --?
    #     :disabled - (default: false)
    #     :choices - array of valid choices, e.g: [:blue, :green, :red]
    #     :set - (:value_to_set_target_variable) value to set if option specified (use for switches where --blue means set @color = 'blue')
    #     :no_accessor - (:do_not_create_accessor) don't class_eval 'attr_accessor :#{target_variable}'
    #     :var - (:target_variable) name of instance variable to set
    #     :target_container - name of object to set instance value
    #
    # if block is passed it is used as :method
    #
    def opt(long_name, *extra_stuff, &b)
      factory_hash = opt_get_top_of_stack

      # Ensure long name is in the proper string format.
      long_name = long_name.to_s
      unless long_name.starts_with? "--"
        long_name = "--#{long_name.gsub(/_/,'-')}"
      end
      factory_hash[:var] = long_name[2..-1].gsub(/-/, '_').gsub(/[^0-9a-zA-Z]/, '_')

      # Create hash for processed options.
      maybe_hash = extra_stuff[-1]
      if maybe_hash.is_a? Hash
        # if maybe_hash is a Hash, then the rest of extra_stuff is an array, which
        # is expected to be:
        #   NOTE (String)
        # or:
        #   TYPE (Symbol)
        # or:
        #   REQUIREMENT (Symbol)
        extra_stuff.pop
        factory_hash.merge! maybe_hash
      end

      # Iterate through and process all of the other arguments.
      while extra_stuff.length > 0
        extra = extra_stuff.shift
        if extra.is_a? Symbol
          if [:required, :optional, :none].include? extra
            factory_hash[:argument] = extra
          elsif Option.all_option_types.include? extra
            factory_hash[:type] = extra
          else
            raise MisconfiguredOptionError.new("#{long_name}: extra options: #{extra.inspect} are not understood")
          end
        elsif extra.is_a? String
          factory_hash[:note] = extra
        else
          raise MisconfiguredOptionError.new("#{long_name}: extra options: #{extra.inspect} are not understood")
        end
      end

      unless factory_hash[:type]
        # If we are not just setting a switch, then we can use the default value
        # and assume this switch has a required argument.
        if factory_hash[:default].present? && factory_hash[:set].nil?
          type = OptionType.find_by_value(factory_hash[:default]).try(:short_name)
          factory_hash[:type] = type unless type.nil?
        end
      end

      # Determine argument requirement type.
      factory_hash[:argument] = if factory_hash[:argument] == :required
                                  ::Af::OptionParser::GetOptions::REQUIRED_ARGUMENT
                                elsif factory_hash[:argument] == :none
                                  ::Af::OptionParser::GetOptions::NO_ARGUMENT
                                elsif factory_hash[:argument] == :optional
                                  ::Af::OptionParser::GetOptions::OPTIONAL_ARGUMENT
                                elsif factory_hash[:argument] == nil
                                  if factory_hash[:type]
                                    if factory_hash[:type] == :switch
                                      ::Af::OptionParser::GetOptions::OPTIONAL_ARGUMENT
                                    else
                                      ::Af::OptionParser::GetOptions::REQUIRED_ARGUMENT
                                    end
                                  else
                                    factory_hash[:type] = :switch
                                    ::Af::OptionParser::GetOptions::OPTIONAL_ARGUMENT
                                  end
                                else
                                  factory_hash[:argument]
                                end

      # Determine argument type if it is not explictly given
      unless factory_hash[:type]
        if factory_hash[:set]
          type = OptionType.find_by_value(factory_hash[:set]).try(:short_name)
          factory_hash[:type] = type unless type.nil?
        end
      end

      # Add the switch to the store, along with all of it's options.
      if factory_hash[:short]
        short = factory_hash[:short].to_s
        unless short[0] == '-'
          short = "-#{short}"
        end
        factory_hash[:short] = short
      end

      if factory_hash[:type]
        type = OptionType.find_by_short_name(factory_hash[:type])
        raise MisconfiguredOptionError.new("#{long_name}: option type #{factory_hash[:type].inspect} is not recognized. (valid option types: #{OptionType.valid_option_type_names.join(', ')})") unless type
        factory_hash[:type]  = type
      end

      factory_hash[:method] = b if b

      # rename keys in factory hash from the UI names to the API names

      {
        :default => :default_value,
        :type => :option_type,
        :var => :target_variable,
        :set => :value_to_set_target_variable,
        :no_accessor => :do_not_create_accessor,
        :group => :option_group_name,
        :short => :short_name,
        :method => :evaluation_method,
        :argument => :requirements
      }.each do |current_key_name,new_key_name|
        if factory_hash.has_key? current_key_name
          factory_hash[new_key_name] = factory_hash.delete(current_key_name)
        end
      end

      Option.factory(long_name, factory_hash)
    end

    def opt_error(text)
      puts text
      Helper.new.help(usage)
      exit 1
    end

    def usage
      return "USAGE: rails runner #{self.name}.run [OPTIONS]"
    end

  end
end
