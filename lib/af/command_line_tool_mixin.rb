module Af
  module CommandLineToolMixin
    def self.included(base)
      base.extend(ClassMethods)
    end

    def application_version
      return "#{self.class.name}: unknown application version"
    end

    def usage
      return @usage
    end

    def help(command_line_usage)
      puts(command_line_usage)
      rows = []
      command_line_options_store.keys.sort.each{|long_switch|
        parameters = command_line_options_store[long_switch]
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
        notes = ""
        if parameters[:default].present?
          notes << "(default: #{parameters[:default]}) "
        end
        notes << (parameters[:note] || "")
        if parameters[:environment_variable]
          notes << " [env: #{parameters[:environment_variable]}]"
        end
        columns << notes
        rows << columns
      }
      puts(self.class.columnized(rows))
    end

    def command_line_options_store
      return self.class.command_line_options_store
    end

    def command_line_options(options = {}, usage = nil)
      if usage.nil?
        @usage = "rails runner #{self.name}.run [OPTIONS]"
      else
        @usage = usage
      end
      command_line_options_store.merge!(options.merge({
                       "--?" => {
                         :short => "-?",
                         :argument => ::Af::GetOptions::NO_ARGUMENT,
                         :note => "show this help"
                       },
                       "--application-version" => {
                         :short => "-V",
                         :argument => ::Af::GetOptions::NO_ARGUMENT,
                         :note => "application version"
                       },
                     }))
      found_system_parameter = false
      if (command_line_options_store.keys.include?('--help') ||
          command_line_options_store.keys.include?('--environment') ||
          command_line_options_store.keys.include?('--version'))
        found_system_parameter = true
      end

      command_line_options_store.each do |key,value|
        if ['-v', '-h', '-e'].include? value[:short]
          found_system_parameter = true
          break
        end
      end

      if found_system_parameter
        raise "#{self.class.name}: ::Af::Application can not set options '-h', '--help', '-e', '--environment', '--version', '-v'.  These are used by rails runner for some ungodly reason."
      end
      command_line_options_store.merge!({
                                          "--help" => {
                                            :short => "-h",
                                            :argument => ::Af::GetOptions::NO_ARGUMENT,
                                            :note => "rails runner help.  use --? for application help."
                                          },
                                          "--environment" => {
                                            :short => "-e",
                                            :argument => ::Af::GetOptions::REQUIRED_ARGUMENT,
                                            :note => "rails environment to run under (development/production/test)",
                                            :argument_note => "NAME",
                                            :env => "RAILS_ENV"
                                          },
                                          "--versions" => {
                                            :short => "-v",
                                            :argument => ::Af::GetOptions::NO_ARGUMENT,
                                            :note => "rails version (use --application-version or -V or version of application)",
                                          }
                                        })
      command_line_options_store.each do |long_name,options|
        unless options[:var]
          var_name = long_name[2..-1].gsub(/-/, '_').gsub(/[^0-9a-zA-Z]/, '_')
          options[:var] = var_name
        end
        if options[:var]
          self.instance_variable_set("@#{options[:var]}".to_sym, options[:default])
        end
      end
      get_options = ::Af::GetOptions.new(command_line_options_store)
      get_options.each{|option,argument|
        if option == '--?'
          help(usage)
          exit 0
        elsif option == '--application-version'
          puts application_version
          exit 0
        else
          command_line_option = command_line_options_store[option]
          if command_line_option.nil?
            puts "unknown option: #{option}"
            help(usage)
            exit 0
          elsif command_line_option.is_a?(Hash)
            argument_value = self.class.evaluate_argument_for_type(argument,
                                                                   (command_line_options_store[:method] || "string"),
                                                                   command_line_options_store[:argument])
            if command_line_option[:method]
              argument_value = command_line_option[:method].call(option, argument_value)
            end
            if command_line_option[:var]
              self.instance_variable_set("@#{command_line_option[:var]}".to_sym, argument_value)
            end
          end
          option_handler(option, argument)
        end
      }
    end

    module ClassMethods
      def command_line_options_store
        @command_line_options_store ||= {}
        return @command_line_options_store
      end

      def opt(long_name = nil, *extra_stuff, &b)
        if b && long_name.nil?
          yield
          return
        end

        if long_name.nil?
          raise "::Af::CommandLineToolMixin: no name given for option"
        end

        extras = extra_stuff[-1]
        if extras.is_a? Hash
          extra_stuff.pop
        else
          extras = {}
        end

        while extra_stuff.length > 0
          extra = extra_stuff.shift
          if extra.is_a?(Symbol)
            if [:required, :optional, :none].include?(extra)
              extras[:argument] = extra
            elsif [:int, :float, :string, :uri, :date, :time,:ints,:floats,:strings,:uris,:dates,:times].include?(extra)
              extras[:type] = extra
            else
              raise "#{long_name}: i don't know what to do with ':#{extra}' on this option"
            end
          elsif extra.is_a?(String)
            extras[:note] = extra
          else
            raise "#{long_name}: i don't know what to do with '#{extra}' on this option"
          end
        end

        long_name = long_name.to_s
        unless long_name[0..1] == "--"
          long_name = "--#{long_name.gsub(/_/,'-')}" 
        end
        unless extras[:type]
          if extras[:default]
            type = ruby_value_to_type_name(extras[:default])
            extras[:type] = type unless type.nil?
          end
        end
        argument = case extras[:argument]
                   when :required
                     ::Af::GetOptions::REQUIRED_ARGUMENT
                   when :none
                     ::Af::GetOptions::NO_ARGUMENT
                   when :optional
                     ::Af::GetOptions::OPTIONAL_ARGUMENT
                   when nil
                     if extras[:type]
                       ::Af::GetOptions::REQUIRED_ARGUMENT
                     else
                       ::Af::GetOptions::NO_ARGUMENT
                     end
                   else
                     extras[:argument]
                   end
        command_line_options_store[long_name] = {
          :argument => argument
        }
        command_line_options_store[long_name][:note] = extras[:note] if extras[:note]
        if extras[:short]
          short = extras[:short]
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
        command_line_options_store[long_name][:method] = extras[:method] if extras[:method]
        command_line_options_store[long_name][:method] = b if b
      end

      def opt_error(text)
        puts text
        help(usage)
        exit 1
      end

      def argument_note_for_type(type_name)
        case type_name
        when :int
          "INTEGER"
        when :float
          "NUMBER"
        when :string
          "STRING"
        when :uri
          "URL"
        when :date
          "DATE"
        when :time
          "TIME"
        when :ints
          "INT1,INT2,INT3..."
        when :floats
          "NUM1,NUM2,NUM3..."
        when :strings
          "STR1,STR2,STR3..."
        when :uris
          "URL1,URL2,URL3..."
        when :dates
          "DATE1,DATE2,DATE3..."
        when :times
          "TIME1,TIME2,TIME3..."
        else
          nil
        end
      end

      def evaluate_argument_for_type(argument, type_name, argument_type)
        case type_name
        when :int
          return argument.to_i
        when :float
          return argument.to_f
        when :string
          return argument.to_s
        when :uri
          return URI.parse(argument)
        when :date
          return Time.zone.parse(argument).to_date
        when :time
          return Time.zone.parse(argument)
        when :ints
          return argument.split(',').map(&:to_i)
        when :floats
          return argument.split(',').map(&:to_f)
        when :strings
          return argument.split(',').map(&:to_s)
        when :uris
          return argument.split(',').map{|a| URI.parse(a)}
        when :dates
          return argument.split(',').map{|a| Time.zone.parse(a).to_date}
        when :times
          return argument.split(',').map{|a| Time.zone.parse(a)}
        else
          if argument_type == ::Af::GetOptions::REQUIRED_ARGUMENT
            argument = true
          end
          return argument
        end
      end

      def ruby_value_to_type_name(value)
        case value.class
        when Fixnum
          :int
        when Float
          :float
        when String
          :string
        when URI::HTTP
          :uri
        when Date
          :date
        when Time
          :time
        when DateTime
          :time
        when Array
          case value.first.class
          when Fixnum
            :ints
          when Float
            :floats
          when String
            :strings
          when URI::HTTP
            :uris
          when Date
            :dates
          when Time
            :times
          when DateTime
            :times
          else
            nil
          end
        else
          nil
        end
      end

      def columnized_row(fields, sized)
        r = []
        fields.each_with_index do |f, i|
          r << sprintf("%0-#{sized[i]}s", f.to_s.gsub(/\\n\\r/, '').slice(0, sized[i]))
        end
        r.join('   ')
      end

      def columnized(rows, options = {})
        sized = {}
        rows.each do |row|
          row.each_index do |i|
            value = row[i]
            sized[i] = [sized[i].to_i, value.to_s.length].max
            sized[i] = [options[:max_width], sized[i].to_i].min if options[:max_width]
          end
        end

        table = []
        rows.each { |row| table << "    " + columnized_row(row, sized).rstrip }
        table.join("\n")
      end
    end
  end
end
