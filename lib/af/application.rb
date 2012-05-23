require 'log4r'
require 'log4r/configurator'
require 'log4r/outputter/consoleoutputters'

module Af
  class Application
    include ::Af::CommandLineToolMixin

    opt :daemon, "run as daemon", :short => :d

    attr_accessor :has_errors, :daemon

    @@singleton = nil

    def self.singleton
      fail("@@singleton not initialized! Maybe you are using a Proxy before creating an instance?") unless @@singleton
      return @@singleton
    end

    def initialize
      @@singleton = self
      @logger = nil
      @logger_level = Log4r::ALL
      @log4r_name_suffix = ""
      @log4r_formatter = nil
    end

    def name
      return self.class.name
    end

    def log4r_custum_levels
      return Log4r::Configurator.custom_levels(:DEBUG, :INFO, :WARN, :ALARM, :ERROR, :FATAL)
    end

    def log4r_name_suffix
      return @log4r_name_suffix
    end

    def set_new_log4r_name_suffix(new_log4r_name_suffix)
      @log4r_name_suffix = new_log4r_name_suffix
      @log4r_outputter.formatter = log4r_formatter
      return @log4r_name_suffix
    end

    def log4r_pattern_formatter_format
      return "%l %C#{log4r_name_suffix} %M"
    end

    def log4r_formatter
      return Log4r::PatternFormatter.new(:pattern => log4r_pattern_formatter_format)
    end

    def log4r_outputter
      unless @log4r_outputter
        @log4r_outputter = Log4r::StdoutOutputter.new("stdout", :formatter => log4r_formatter)
      end
      return @log4r_outputter
    end

    def logger_level
      return @logger_level
    end

    def logger_level=(new_logger_level)
      return @logger_level = new_logger_level
    end

    def logger
      unless @logger
        log4r_custum_levels
        @logger = Log4r::Logger.new(name)
        @logger.outputters = log4r_outputter
        @logger.level = logger_level
      end
      return @logger
    end

    def self.run(*arguments)
      # this ARGV hack is here for test specs to add script arguments
      ARGV[0..-1] = arguments if arguments.length > 0
      self.new.run
    end

    def run(usage = nil, options = {})
      @options = options
      @usage = (usage or "#{self.class.name} [OPTIONS]")

      command_line_options(@options, @usage)

      work unless handle_one_time_command_switches

      exit @has_errors ? 1 : 0
    end

    protected
    def option_handler(option, argument)
      if option == '--daemon'
        Daemons.daemonize
        cleanup_after_fork
      end
    end

    # Overload to impose constraints on parsed arguments.  MUST call super().
    # Return true to terminate immediately without calling work.
    # Return false for normal processing.
    def handle_one_time_command_switches
      return false
    end

    def cleanup_after_fork
      ActiveRecord::Base.connection.disconnect!
      ActiveRecord::Base.establish_connection
    end

    module Proxy
      def logger
        return ::Af::Application.singleton.logger
      end

      def name
        return ::Af::Application.singleton.name
      end
    end
  end
end
