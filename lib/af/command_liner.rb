module Af

  # Utility base class for executing Ruby scripts on the command line. Provides
  # methods to define, gather, parse and cast command line options. Options are
  # stored as class instance variables.
  class CommandLiner

    ### Class methods ###

    # Return the command line options store for just this class.
    def self.command_line_options_store
      @command_line_options_store ||= {}
      return @command_line_options_store
    end

    # Return the command line options groups store for just this class.
    def self.command_line_option_groups_store
      @command_line_option_groups_store ||= {}
      return @command_line_option_groups_store
    end

    # Declare a command line options group.
    #
    # *Arguments*
    #   * group_name - name of the group
    #   * group_title - title of the group (optional)
    #
    def self.opt_group(group_name, *extra_stuff)
      command_line_option_groups_store[group_name] ||= {}

      maybe_title = extra_stuff.shift
      if maybe_title.is_a? String
        command_line_option_groups_store[group_name][:title] = maybe_title
      else
        extra_stuff.shift(maybe_title)
      end

      maybe_hash = extra_stuff[-1]
      if maybe_hash.is_a? Hash
        # TODO AK: What are other possible values in "maybe_hash" below?
        command_line_option_groups_store[group_name].merge!(maybe_hash)
      end

      # TODO AK: What are the obvious errors?
      # ignoring obvious errors
    end

    def self.opt_assign_group(opt_name, group_name)
      command_line_option_groups_store[group_name] ||= {}
      command_line_option_groups_store[group_name].merge!({:group => opt_name})
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
    def self.opt(long_name = nil, *extra_stuff, &b)

      # TODO AK: What does yielding to block here accomplish?
      if b && long_name.nil?
        yield
        return
      end

      if long_name.nil?
        # TODO AK: This should probably be an ArgumentError exception.
        raise "::Af::CommandLiner: no name given for option"
      end

      # Create hash for processed options.
      extras = extra_stuff[-1]
      if extras.is_a? Hash
        # TODO AK: Why remove the last argument?  What does it contain?
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
          elsif [:int, :float, :string, :uri, :date, :time, :choice, :hash, :ints, :floats, :strings, :uris, :dates, :times, :choices].include?(extra)
            extras[:type] = extra
          else
            # TODO AK: This should probably be an ArgumentError exception.
            raise "#{long_name}: i don't know what to do with ':#{extra}' on this option"
          end
        elsif extra.is_a?(String)
          extras[:note] = extra
        else
          # TODO AK: This should probably be an ArgumentError exception.
          raise "#{long_name}: i don't know what to do with '#{extra}' on this option"
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
          type = ruby_value_to_type_name(extras[:default])
          extras[:type] = type unless type.nil?
        end
      end

      # Determine argument type.
      argument = if extras[:argument] == :required
                   ::Af::GetOptions::REQUIRED_ARGUMENT
                 elsif extras[:argument] == :none
                   ::Af::GetOptions::NO_ARGUMENT
                 elsif extras[:argument] == :optional
                   ::Af::GetOptions::OPTIONAL_ARGUMENT
                 elsif extras[:argument] == nil
                   if extras[:type]
                     ::Af::GetOptions::REQUIRED_ARGUMENT
                   else
                     ::Af::GetOptions::NO_ARGUMENT
                   end
                 else
                   extras[:argument]
                 end

      unless extras[:type]
        if extras[:set]
          type = ruby_value_to_type_name(extras[:set])
          extras[:type] = type unless type.nil?
        end
      end

      # Add the switch to the store, along with all of it's options.
      command_line_options_store[long_name] = {
        :argument => argument
      }
      command_line_options_store[long_name][:note] = extras[:note] if extras[:note]
      if extras[:short]
        short = extras[:short].to_s
        unless short[0] == '-'
          short = "-#{short}"
        end
        command_line_options_store[long_name][:short] = short
      end
      command_line_options_store[long_name][:argument_note] = extras[:argument_note] if extras[:argument_note]
      command_line_options_store[long_name][:environment_variable] = extras[:environment_variable] if extras[:environment_variable]
      command_line_options_store[long_name][:environment_variable] = extras[:env] if extras[:env]
      command_line_options_store[long_name][:default] = extras[:default] if extras[:default]
      command_line_options_store[long_name][:type] = extras[:type] if extras[:type]
      command_line_options_store[long_name][:var] = extras[:var] if extras[:var]
      command_line_options_store[long_name][:set] = extras[:set] if extras[:set]
      command_line_options_store[long_name][:method] = extras[:method] if extras[:method]
      command_line_options_store[long_name][:method] = b if b
      command_line_options_store[long_name][:group] = extras[:group] if extras[:group].present?
      command_line_options_store[long_name][:hidden] = extras[:hidden] if extras[:hidden].present?
      command_line_options_store[long_name][:choices] = extras[:choices] if extras[:choices].present?
      command_line_options_store[long_name][:no_accessor] = extras[:no_accessor] if extras[:no_accessor].present?
    end

    # TODO AK: This doesn't seem to be used anywhere.  Maybe it can be removed?
    def self.opt_error(text)
      puts text
      help(usage)
      exit 1
    end

    # Convert the provided option type name into a string used in notes.
    def self.argument_note_for_type(type_name)
      if type_name == :int
        "INTEGER"
      elsif type_name == :float
        "NUMBER"
      elsif type_name == :string
        "STRING"
      elsif type_name == :uri
        "URL"
      elsif type_name == :date
        "DATE"
      elsif type_name == :time
        "TIME"
      elsif type_name == :choice
        "CHOICE"
      elsif type_name == :hash
        "K1=V1,K2=V2,K3=V3..."
      elsif type_name == :ints
        "INT1,INT2,INT3..."
      elsif type_name == :floats
        "NUM1,NUM2,NUM3..."
      elsif type_name == :strings
        "STR1,STR2,STR3..."
      elsif type_name == :uris
        "URL1,URL2,URL3..."
      elsif type_name == :dates
        "DATE1,DATE2,DATE3..."
      elsif type_name == :times
        "TIME1,TIME2,TIME3..."
      elsif type_name == :choices
        "CHOICE1,CHOICE2,CHOICE3..."
      else
        nil
      end
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
        if argument_availability == ::Af::GetOptions::REQUIRED_ARGUMENT
          argument = true
        end
        return argument
      end
    end

    # Convert the provided class constant into it's symbol option
    # name.
    def self.ruby_value_to_type_name(value)
      if value.class == Fixnum
        :int
      elsif value.class == Float
        :float
      elsif value.class == String
        :string
      elsif value.class == URI::HTTP
        :uri
      elsif value.class == Date
        :date
      elsif value.class == Time
        :time
      elsif value.class == DateTime
        :time
      elsif value.class == Symbol
        :choice
      elsif value.class == Hash
        :hash
      elsif value.class == Array
        if value.first.class == Fixnum
          :ints
        elsif value.first.class == Float
          :floats
        elsif value.first.class == String
          :strings
        elsif value.first.class == URI::HTTP
          :uris
        elsif value.first.class == Date
          :dates
        elsif value.first.class == Time
          :times
        elsif value.first.class == DateTime
          :times
        elsif value.first.class == Symbol
          :choices
        else
          nil
        end
      else
        nil
      end
    end

    # Convert an array into a single string, where each item consumes a static
    # number of characters.  Long fields are truncated and small ones are padded.
    #
    # *Arguments*
    #   * fields - array of objects that respond to "to_s"
    #   * sized - character count for each field in the new string????
    def self.columnized_row(fields, sized)
      r = []
      fields.each_with_index do |f, i|
        r << sprintf("%0-#{sized[i]}s", f.to_s.gsub(/\\n\\r/, '').slice(0, sized[i]))
      end
      return r.join('   ')
    end

    # Converts an array of arrays into a single array of columnized strings.
    #
    # *Arguments*
    #   * rows - arrays to convert
    #   * options - hash of options, includes:
    #     :max_width => <integer max width of columns>
    def self.columnized(rows, options = {})
      sized = {}
      rows.each do |row|
        row.each_index do |i|
          value = row[i]
          sized[i] = [sized[i].to_i, value.to_s.length].max
          sized[i] = [options[:max_width], sized[i].to_i].min if options[:max_width]
        end
      end

      return rows.map { |row| "    " + columnized_row(row, sized).rstrip }
    end

    ### Instance Methods ###

    # Returns the current version of the application.
    # *Must be overridden in a subclass.*
    def application_version
      return "#{self.name}: unknown application version"
    end

    # Returns a string detailing application usage.
    def usage
      return @usage
    end

    # Prints to stdout application usage and all command line options.
    def help(command_line_usage, show_hidden = false)

      # Print usage.
      puts(command_line_usage)

      # Fetch all command line options stores (grouped and not).
      grouped_commands = all_command_line_option_groups_stores
      commands = all_command_line_options_stores

      # Add non-grouped options to grouped as "basic".
      commands.each do |long_switch,configuration|
        group_name = (configuration[:group] || :basic)
        grouped_commands[group_name] ||= {}
        grouped_commands[group_name][:commands] ||= []
        grouped_commands[group_name][:commands] << long_switch
      end

      # Array of strings to be printed to stdout.
      output = []

      # Iterate through all command groups  sorted by priority.
      grouped_commands.keys.sort{|a,b| (grouped_commands[a][:priority] || 50) <=> (grouped_commands[b][:priority] || 50)}.each do |group_name|
        grouped_command = grouped_commands[group_name]

        unless grouped_command[:commands].blank?
          if grouped_command[:hidden] == true && show_hidden == false
            # skipping hidden groups
          else
            output << "#{group_name}: " + grouped_command[:title]
            output << " " + (grouped_command[:description] || "").chomp.split("\n").map(&:strip).join("\n ")

            rows = []

            # Iterate trhough all commands in this group.
            grouped_command[:commands].sort.each do |long_switch|
              parameters = commands[long_switch]
              if parameters[:hidden] == true && show_hidden == false
                # skipping hidden commands
              else
                columns = []
                switches = "#{long_switch}"
                if (parameters[:short])
                  switches << " | #{parameters[:short]}"
                end
                unless (parameters[:argument] == ::Af::GetOptions::NO_ARGUMENT)
                  if (parameters[:argument_note])
                    switches << " #{parameters[:argument_note]}"
                  elsif (parameters[:type])
                    note = self.class.argument_note_for_type(parameters[:type])
                    switches << " #{note}" if note
                  end
                end
                columns << switches
                notes = []
                unless (parameters[:argument] == ::Af::GetOptions::NO_ARGUMENT)
                  if parameters[:default].present?
                    if parameters[:default].is_a? Array
                      notes << "(default: #{parameters[:default].join(',')})"
                    elsif parameters[:default].is_a? Hash
                      notes << "(default: #{parameters[:default].map{|k,v| k.to_s + '=>' + v.to_s}.join(',')}"
                    else
                      notes << "(default: #{parameters[:default]})"
                    end
                  end
                end
                notes << (parameters[:note] || "")
                notes << "(choices: #{parameters[:choices].map(&:to_s).join(', ')})" unless parameters[:choices].blank?
                if parameters[:environment_variable]
                  notes << " [env: #{parameters[:environment_variable]}]"
                end
                columns << notes.join(' ')
                rows << columns
              end
            end
            output += self.class.columnized(rows)
          end
        end
      end

      puts output.join("\n")
    end

    # Return the store of command line options for just this class.
    def command_line_options_store
      return self.class.command_line_options_store
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

    # Returns the union of all command line option stores in the class heirarchy.
    # The result is cached and returned for future calls.
    def all_command_line_options_stores
      unless @all_command_line_options_stores
        @all_command_line_options_stores ||= {}

        self.class.ancestors.reverse.each do |ancestor|
          if ancestor.respond_to?(:command_line_options_store)
            @all_command_line_options_stores.merge!(ancestor.command_line_options_store)
          end
        end
      end
      return @all_command_line_options_stores
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
            type_name = self.class.ruby_value_to_type_name(command_line_option[:set])
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

    # Returns the union of all grouped command line option stores in the class
    # heirarchy. The result is cached and returned for future calls.
    def all_command_line_option_groups_stores
      unless @all_command_line_option_groups_stores
        @all_command_line_option_groups_stores ||= {}

        self.class.ancestors.reverse.each do |ancestor|
          if ancestor.respond_to?(:command_line_option_groups_store)
            @all_command_line_option_groups_stores.merge!(ancestor.command_line_option_groups_store)
          end
        end
      end
      return @all_command_line_option_groups_stores
    end

    # A number of default command line switches and switch groups available to all
    # subclasses.
    opt '?', "show this help (--?? for all)", :short => '?', :group => :basic
    opt '??', "show help for all commands", :group => :basic, :hidden => true
    opt :application_version, "application version", :short => :V, :group => :basic

    opt_group :basic, "basic options", :priority => 0, :description => <<-DESCRIPTION
      These are the stanadard options offered to all Af commands.
    DESCRIPTION
    opt_group :advanced, "advanced options", :priority => 100, :hidden => true, :description => <<-DESCRIPTION
      These are advanced options offered to this programs.
    DESCRIPTION

  end
end
