module ::Af::OptionParser
  class Helper
    def initialize(grouped_commands, commands)
    end

    # Prints to stdout application usage and all command line options.
    def help(command_line_usage, show_hidden = false)
      columnizer = Columnizer.new

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
            output += columnizer.columnized(rows)
          end
        end
      end

      puts output.join("\n")
    end
  end
end
