module ::Af::OptionParser
  class Helper
    def initialize
      @options = Option.all_options
      @grouped_options = @options.values.group_by{|option| option.option_group_name || :basic}
      @groups = OptionGroup.option_groups.values.sort{|a,b| (a.priority || 50) <=> (b.priority || 50)}
    end

    # Prints to stdout application usage and all command line options.
    def help(command_line_usage, show_hidden = false)
      # Print usage.
      puts(command_line_usage)

      # Array of strings to be printed to stdout.
      output = []

      # Iterate through all command groups  sorted by priority.
      @groups.each do |group|
        options_in_group = @grouped_options[group.group_name]
        unless options_in_group.blank?
          if group.hidden == true && show_hidden == false
            # skipping hidden groups
          else
            output << "#{group.group_name}: #{group.title}"
            output << " " + (group.description || "").chomp.split("\n").map(&:strip).join("\n ")

            rows = []

            # Iterate trhough all commands in this group.
            options_in_group.sort{|a,b| a.long_name <=> b.long_name}.each do |option|
              if option.hidden == true && show_hidden == false
                # skipping hidden commands
              else
                columns = []
                switches = "#{option.long_name}"
                if (option.short_name)
                  switches << " | #{option.short_name}"
                end
                unless (option.requirements == ::Af::OptionParser::GetOptions::NO_ARGUMENT)
                  if (option.argument_note)
                    switches << " #{option.argument_note}"
                  elsif (option.option_type)
                    note = OptionType.find_by_short_name(option.option_type).try(:argument_note)
                    switches << " #{note}" if note
                  end
                end
                columns << switches
                notes = []
                unless (option.requirements == ::Af::OptionParser::GetOptions::NO_ARGUMENT)
                  if option.default_value.present?
                    if option.default_value.is_a? Array
                      notes << "(default: #{option.default_value.join(',')})"
                    elsif option.default_value.is_a? Hash
                      notes << "(default: #{option.default_value.map{|k,v| k.to_s + '=>' + v.to_s}.join(',')}"
                    else
                      notes << "(default: #{option.default_value})"
                    end
                  end
                end
                notes << (option.note || "")
                notes << "(choices: #{option.choices.map(&:to_s).join(', ')})" unless option.choices.blank?
                if option.environment_variable
                  notes << " [env: #{option.environment_variable}]"
                end
                columns << notes.join(' ')
                rows << columns
              end
            end
            output += Columnizer.new.columnized(rows)
          end
        end
      end

      puts output.join("\n")
    end
  end
end
