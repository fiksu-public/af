module Af
  module CommandLineToolMixin

    # options
    #  :short
    #  :argument_note
    #  :environment_variable
    #  :note
    #  :argument
    #
    #  :method - raise error if bad
    #  :var

    def usage
      return @usage
    end

    def self.opt(*a)
      raise 'SELF.FOO'
    end

    def opt(*a)
      raise 'FOO'
    end


    def xopt(long_name = nil, *extra_stuff, &b)
      @command_line_options ||= {}
      if b && long_name.nil?
        yield
        return
      end

      extras = extra_stuff[-1]
      if extra.is_a? Hash
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

      unless long_name[0..1] == "--"
        long_name = "--#{long_name.gsub(/_/,'-')}" 
      end
      long_name = "--#{long_name}" 
      argument = case extras[:argument]
                 when :required
                   ::Af::GetOptions::REQUIRED_ARGUMENT
                 when :none
                   ::Af::GetOptions::NO_ARGUMENT
                 when :optional
                   ::Af::GetOptions::OPTIONAL_ARGUMENT
                 when nil
                   ::Af::GetOptions::NO_ARGUMENT
                 else
                   extras[:argument]
                 end
      @command_line_options[long_name] = {
        :argument => argument
      }
      @command_line_options[long_name][:note] = extra[:note] if extras[:note]
      @command_line_options[long_name][:short] = extra[:short] if extras[:short]
      @command_line_options[long_name][:argument_note] = extra[:argument_note] if extras[:argument_note]
      @command_line_options[long_name][:environment_variable] = extra[:environment_variable] if extras[:environment_variable]
      @command_line_options[long_name][:environment_variable] = extra[:env] if extras[:env]
      @command_line_options[long_name][:default] = extra[:default] if extras[:default]
      @command_line_options[long_name][:type] = extra[:type] if extras[:type]
      @command_line_options[long_name][:var] = extra[:var] if extras[:var]
      @command_line_options[long_name][:method] = extra[:method] if extras[:method]
      @command_line_options[long_name][:method] = b if b
    end

    def opt_error(text)
      puts text
      help(usage, @command_line_options)
      exit 1
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

    def help(command_line_usage, command_line_options)
      puts(command_line_usage)
      rows = []
      command_line_options.keys.sort.each{|long_switch|
        parameters = command_line_options[long_switch]
        columns = []
        switches = "#{long_switch}"
        if (parameters[:short])
          switches << " | #{parameters[:short]}"
        end
        unless (parameters[:argument] == :none)
          if (parameters[:argument_note])
            switches << " #{parameters[:argument_note]}"
          elsif (parameters[:type])
            note = argument_note_for_type(parameters[:type])
            switches << " #{note}" if note
          end
        end
        columns << switches
        notes = ""
        if parameter[:default].present?
          notes << "(#{parameter[:default]}) "
        end
        notes << (parameters[:note] || "")
        columns << notes
        columns << (parameters[:environment_variable] or "")
        rows << columns
      }
      puts(columnized(rows))
    end

    def command_line_options(options = {}, usage = nil)
      if usage.nil?
        @usage = "#{self.name} [OPTIONS]"
      else
        @usage = usage
      end
      @command_line_options.merge!(options.merge({
                       "--?" => {
                         :short => "-?",
                         :argument => ::Af::GetOptions::NO_ARGUMENT,
                         :note => "show this help"
                       },
                     }))
      if (@command_line_options.keys.include?('--help') ||
          @command_line_options.keys.include?('-h') ||
          @command_line_options.keys.include?('--environment') ||
          @command_line_options.keys.include?('-e'))
        raise "Can't set options '-h', '--help', '-e', '--environment'.  these are used by rails for some ungodly reason"
      end
      @command_line_options.merge!({
                                     "--help" => {
                                       :short => "-h",
                                       :argument => ::Af::GetOptions::NO_ARGUMENT,
                                       :note => "rails runner help.  use --? for script help."
                                     },
                                     "--environment" => {
                                       :short => "-e",
                                       :argument => ::Af::GetOptions::ARGUMENT_REQUIRED,
                                       :note => "rails environment to run under (development/production/test)",
                                       :argument_note => "NAME"
                                     }
                                   })
      get_options = ::Af::GetOptions.new(@command_line_options)
      get_options.each{|option,argument|
        if option == '--?'
          help(usage, options)
          exit 0
        else
          option_handler(option, argument)
        end
      }
    end
  end
end
