require 'getoptlong'

module Af

  # Subclasses Getoptlong from the Ruby standard library.
  # See: http://www.ruby-doc.org/stdlib-1.9.3/libdoc/getoptlong/rdoc/GetoptLong.html.
  class GetOptions < GetoptLong
    ARGUMENT_FLAGS = [
      NO_ARGUMENT = GetoptLong::NO_ARGUMENT,
      REQUIRED_ARGUMENT = GetoptLong::REQUIRED_ARGUMENT,
      OPTIONAL_ARGUMENT = GetoptLong::OPTIONAL_ARGUMENT
    ]

    # Instantiate a new long command line option parser with a hash of switches.
    #
    # *Arguments*
    #   * switches - optional hash of command line switches in the form of:
    #       { <long switch> => {
    #         :short => <optional short switch>,
    #         :argument => <constant arg type>,
    #         :environment_variable => How do these work???
    #         :note => <arg description>
    #       }
    def initialize(switches = {})
      # TODO AK: I think these can all just be local variables.
      # TODO AK: This isn't used, can it be removed?
      @command_line_switchs = switches
      @environment_variables = {} # switches that are set in the ENV
      @getopt_options = []

      # Iterate through all of the switches.
      switches.each do |long_switch, parameters|

        # Set aside 
        if parameters[:environment_variable].present?
          @environment_variables[parameters[:environment_variable]] = long_switch
        end

        # Convert hash into array, in format expected by Getoptlong#new.
        # Example: ['--foo', '-f', 'bar']
        options = []
        options << long_switch
        if (parameters[:short])
          options << parameters[:short]
        end
        options << parameters[:argument]
        @getopt_options << options

      end

      # Add enviroment variables to the front of ARGV.
      argv_additions = []
      for environment_variable_name,value in @environment_variables do
        if ENV[environment_variable_name]
        argv_additions << value
        argv_additions << ENV[environment_variable_name] unless ENV[environment_variable_name].empty?
        end
      end
      for arg in ARGV do
        argv_additions << arg
      end

      # Rewrite ARGV with environment variable with the new list.
      argv_additions.each_with_index { |v,i| ARGV[i] = v }

      super(*@getopt_options)
    end
  end
end
