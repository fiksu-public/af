require 'getoptlong'

module Af::OptionParser
  # Subclasses Getoptlong from the Ruby standard library.
  # Docs: http://www.ruby-doc.org/stdlib-1.9.3/libdoc/getoptlong/rdoc/GetoptLong.html.
  # Source: https://github.com/ruby/ruby/blob/trunk/lib/getoptlong.rb.
  class GetOptions < GetoptLong

    # Local constants which map to superclass argument types.
    ARGUMENT_FLAGS = [
      NO_ARGUMENT = GetoptLong::NO_ARGUMENT,
      REQUIRED_ARGUMENT = GetoptLong::REQUIRED_ARGUMENT,
      OPTIONAL_ARGUMENT = GetoptLong::OPTIONAL_ARGUMENT
    ]

    # Instantiate a new long command line option parser with a hash of switches.
    #
    # *Arguments*
    #   * switches - optional hash of command line switches, with long switch as
    #       key to a set of options:
    #         :short => <optional short switch>
    #         :argument => <constant arg type>
    #         :environment_variable => <how do these work???>
    #         :note => <arg description>
    def initialize(declared_options = [])
      getopt_options = []
      argv_additions = []

      # Iterate through all of the options.
      declared_options.each do |option|
        # Set aside
        if option.environment_variable.present?
          # Add enviroment variables to the front of ARGV.
          if ENV[option.environment_variable]
            argv_additions << option.long_name
            unless ENV[option.environment_variable].empty?
              # if the envvar is empty we assume this is a switch (no parameter)
              argv_additions << ENV[option.environment_variable]
            end
          end
        end

        # Convert hash into array, in format expected by Getoptlong#new.
        # Example: ['--foo', '-f', GetoptLong::NO_ARGUMENT]
        options = []
        options << option.long_name
        if (option.short_name)
          options << option.short_name
        end
        options << option.requirements
        getopt_options << options
      end

      # add any ARGVs to our list
      for arg in ARGV do
        argv_additions << arg
      end

      # Rewrite ARGV with environment variable with the new list.
      argv_additions.each_with_index { |v,i| ARGV[i] = v }

      super(*getopt_options)
    end
  end
end
