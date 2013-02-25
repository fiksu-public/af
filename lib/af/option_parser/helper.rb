module ::Af::OptionParser
  class Helper
    def initialize(options)
      @options = options
      @grouped_options = options.group_by{|option| option.option_group_name || :basic}
    end

    # Prints to stdout application usage and all command line options.
    def help(command_line_usage, show_hidden = false)
      # Print usage.
      puts(command_line_usage)

      # Array of strings to be printed to stdout.
      output = []

      # Iterate through all command groups  sorted by priority.
      @grouped_options.keys.sort{|a,b| (@grouped_options[a].priority || 50) <=> (@grouped_options[b].priority || 50)}.each do |group_name|
        grouped_option = @grouped_options[group_name]
        group = OptionGroup.find(group_name)
        unless @grouped_options[:commands].blank?
          if group.hidden == true && show_hidden == false
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
                    note = OptionType.find_by_short_name(parameters[:type])
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
            output += Columnizer.new.columnized(rows)
          end
        end
      end

      puts output.join("\n")
    end
  end
end
