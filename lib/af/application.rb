require 'log4r'
require 'log4r/configurator'
require 'log4r/outputter/consoleoutputters'

module Af
  class Application < ::Af::CommandLiner
    opt :daemon, "run as daemon", :short => :d
    opt :log_dir, "directory to store log files", :default => "/var/log/af"
    opt :log_file, "base name of file to log output"
    opt :log_file_extension, "extension name of file to log output", :default => '.log'
    opt :log_all_output, "start logging output", :default => false

    attr_accessor :has_errors, :daemon, :log_dir, :log_file, :log_file_extension, :log_all_output

    @@singleton = nil

    def self.singleton(safe = false)
      if @@singleton.nil?
        if safe
          @@singleton = new
        else
          fail("Application @@singleton not initialized! Maybe you are using a Proxy before creating an instance? or use SafeProxy")
        end
      end
      return @@singleton
    end

    def initialize
      super
      @@singleton = self
      @logger = nil
      @logger_level = Log4r::ALL
      @log4r_name_suffix = ""
      @log4r_formatter = nil
      ActiveRecord::ConnectionAdapters::ConnectionPool.initialize_connection_application_name(self.class.database_application_name)
      $stdout.sync = true
      $stderr.sync = true
      update_opts :log_file, :default => name
    end

    def self.database_application_name
      return "#{self.name}/#{Process.pid}"
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
      @log4r_outputter.formatter = log4r_formatter if @log4r_outputter
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

      post_command_line_parsing

      work unless handle_one_time_command_switches

      exit @has_errors ? 1 : 0
    end

    protected
    def option_handler(option, argument)
    end

    # Overload to impose constraints on parsed arguments.
    # Return true to terminate immediately without calling work.
    # Return false for normal processing.
    def handle_one_time_command_switches
      return false
    end

    def post_command_line_parsing
      if @daemon
        @log_all_output = true
      end

      if @log_all_output
        path = Pathname.new(@log_dir.to_s)
        path.mkpath
        log_path =  path + "#{@log_file}#{@log_file_extension}"
        $stdout.reopen(log_path, "a")
        $stderr.reopen(log_path, "a")
        $stdout.sync = true
        $stderr.sync = true
      end

      if @daemon
        fork do
          Process.setsid
          trap 'SIGHUP', 'IGNORE'
          cleanup_after_fork
          begin
            ActiveRecord::Base.find_by_sql("select * from pg_stat_activity limit 1");
          rescue
            logger.info "*" * 100
            logger.info "FAILED"
            logger.info "*" * 100
          end
          begin
            ActiveRecord::Base.find_by_sql("select * from pg_stat_activity limit 1");
          rescue
            logger.info "#" * 100
            logger.info "FAILED"
            logger.info "#" * 100
          end
        end
        exit 0
      end
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

    module SafeProxy
      def logger
        return ::Af::Application.singleton(true).logger
      end

      def name
        return ::Af::Application.singleton(true).name
      end
    end
  end
end
