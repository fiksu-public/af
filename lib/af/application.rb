require 'log4r'
require 'log4r/configurator'
require 'log4r/outputter/consoleoutputters'

Log4r::Configurator.custom_levels(:DEBUG, :DEBUG_FINE, :DEBUG_MEDIUM, :DEBUG_GROSS, :DETAIL, :INFO, :WARN, :ALARM, :ERROR, :FATAL)

module Af
  class Application < ::Af::CommandLiner
    DEFAULT_LOG_LEVEL = Log4r::ALL

    opt_group :logging, "logger options", :priority => 100, :hidden => true, :description => <<-DESCRIPTION
      These are options associated with logging. By default, logging is turned on when
      a process is daemonized.
      You can set the log file name in components with --log-dir, --log-file-basename, and --log-file_extension
      which will ensure "log dir" exists. You can also set the file simply with --log-file (the path to the
      log file must exist).
      --log-level is used to turn on and off loggers. Current levels are:
       Log4r::#{Log4r::LNAMES.join(', Log4r::')}
      the parameter for --log-level should be a formated key/value pair where the key is the name
      of the logger ("Process::ExampleProgram" for instance) and log level ("Log4r::DEBUG_MEDIUM") separated by '='
      each key/value pair should be separated by a ','.  the logger name 'default' can be used as the base application
      logger name:
      Process::ExampleProgram=Log4r::DEBUG_MEDIUM,Process::ExampleProgram::SubClassThing=Log4r::DEBUG_FINE
      or:
      default=Log4r::ALL
    DESCRIPTION

    opt :daemon, "run as daemon", :short => :d
    opt :log_dir, "directory to store log files", :default => "/var/log/af", :group => :logging
    opt :log_file_basename, "base name of file to log output", :default => "af", :group => :logging
    opt :log_file_extension, "extension name of file to log output", :default => '.log', :group => :logging
    opt :log_file, "full path name of log file", :type => :string, :env => "AF_LOG_FILE", :group => :logging
    opt :log_all_output, "start logging output", :default => false, :group => :logging
    opt :log_level, "set the levels of one or more loggers", :type => :hash, :env => "AF_LOG_LEVEL", :group => :logging
    opt :log_configuration_file, "load an log4r xml configuration file", :type => :string, :argument_note => 'FILENAME', :group => :logging
    opt :log_with_timestamps, "add timestamps to log output", :env => "AF_LOG_WITH_TIMESTAMPS", :group => :logging

    attr_accessor :has_errors, :daemon, :log_dir, :log_file, :log_file_basebane, :log_file_extension, :log_all_output, :log_level, :log_configuration_file
    attr_accessor :log_with_timestamps

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
      @loggers = {}
      @logger_levels = {:default => DEFAULT_LOG_LEVEL, "Log4r" => Log4r::INFO}
      @log4r_formatter = nil
      @log4r_outputter = {}
      set_connection_application_name(startup_database_application_name)
      $stdout.sync = true
      $stderr.sync = true
      update_opts :log_file_basename, :default => af_name
    end

    def set_connection_application_name(name)
      ActiveRecord::ConnectionAdapters::ConnectionPool.initialize_connection_application_name(name[([name.length - 63,0].max)..-1])
    end

    def startup_database_application_name
      return "#{af_name}(pid: #{Process.pid})"
    end

    def database_application_name
      return self.class.startup_database_application_name
    end

    def af_name
      return self.class.name
    end

    def log4r_logger_name(logger_level)
      return ::Log4r::LNAMES[logger_level]
    end

    def log4r_pattern_formatter_format
      return "#{@log_with_timestamps ? '%d ' : ''}%C %l %M"
    end

    def log4r_formatter(logger_name = :default)
      logger_name = :default if logger_name == af_name
      return Log4r::PatternFormatter.new(:pattern => log4r_pattern_formatter_format, :date_pattern => "%Y-%m-%d %H:%M:%S.%L")
    end

    def log4r_outputter(logger_name = :default)
      logger_name = :default if logger_name == af_name
      unless @log4r_outputter.has_key?(logger_name)
        @log4r_outputter[logger_name] = Log4r::StdoutOutputter.new("stdout", :formatter => log4r_formatter(logger_name))
      end
      return @log4r_outputter[logger_name]
    end

    def logger_level(logger_name = :default)
      logger_name = :default if logger_name == af_name
      return @logger_levels[logger_name] || DEFAULT_LOG_LEVEL
    end

    def set_logger_level(new_logger_level, logger_name = :default)
      logger_name = :default if logger_name == af_name
      @logger_levels[logger_name] = new_logger_level
    end

    def logger(logger_name = :default)
      logger_name = :default if logger_name == af_name
      if logger_name.is_a? String
        # this code is here to fix logger names that people might assume are always
        # prefixed with the af_name.
        while logger_name.start_with? "#{af_name}::"
          logger_name = logger_name[("#{af_name}::".length)..-1]
        end
      end
      unless @loggers.has_key?(logger_name)
        if logger_name == :default
          actual_logger_name = af_name
        else
          # we want logger names prefixed with af_name so that we can find the specific script's
          # logs in log file (by grep "^#{af_name}")
          actual_logger_name = "#{af_name}::#{logger_name}"
        end
        l = Log4r::Logger.new(actual_logger_name)
        l.outputters = log4r_outputter(logger_name)
        l.level = logger_level(logger_name)
        l.additive = false
        @loggers[logger_name] = l
      end
      return @loggers[logger_name]
    end

    def self._run(*arguments)
      # this ARGV hack is here for test specs to add script arguments
      ARGV[0..-1] = arguments if arguments.length > 0
      self.new._run
    end

    def _run(usage = nil, options = {})
      @options = options
      @usage = (usage or "rails runner #{self.class.name}.run [OPTIONS]")

      command_line_options(@options, @usage)

      post_command_line_parsing

      pre_work

      return self
    end

    def pre_work
      set_connection_application_name(database_application_name)
    end

    def _work
      work

      exit @has_errors ? 1 : 0
    end

    def self.run(*arguments)
      application = self.new._run(*arguments)
      application._work
    end

    protected
    def option_handler(option, argument)
    end

    # Overload to do any operations that need to be handled before work is called.
    # call exit if needed.  always call super
    def pre_work
      logger.debug_gross "pre work"
    end

    def logger_logger
      return logger("Log4r")
    end

    def set_logger_levels(log_level_hash)
      logger_logger.debug_gross "set_logger_levels: #{log_level_hash.map{|k,v| k.to_s + ' => ' + v.to_s}.join(', ')}"
      # we need to handle the follow cases:
      #  "x" => 1
      #  "x" => "1"
      #  "x" => "INFO"
      #  "x" => "Log4r::INFO"
      coerced_log_level_hash = Hash[log_level_hash.map { |logger_name, logger_level|
                                      logger_name = :default if logger_name == "default"
                                      if logger_level.is_a? Integer
                                        logger_level_value = logger_level
                                      elsif logger_level.is_a? String
                                        if logger_level[0] =~ /[0-9]/
                                          logger_level_value = logger_level.to_i
                                        else
                                          logger_level_value = logger_level.constantize rescue nil
                                          logger_level_value = "Log4r::#{logger_level}".constantize rescue nil unless logger_level_value
                                        end
                                      end
                                      logger_level_value = DEFAULT_LOG_LEVEL unless logger_level_value
                                      [logger_name, logger_level_value]
                                    }]
      @logger_levels.merge!(coerced_log_level_hash)
      @logger_levels.each do |logger_name, logger_level|
        # Get or create the logger by name
        l = logger(logger_name)
        # Make sure the level is overridden
        l.level = logger_level
        logger_logger.detail "set_logger_levels: #{logger_name} => #{log4r_logger_name(logger_level)}"
      end

      logger_logger.debug_fine "all loggers:"
      Log4r::Logger.each() do |logger_name, logger_obj|
        logger_logger.debug_fine "logger: #{logger_name}: #{logger_obj.inspect}"
      end

    end

    def post_command_line_parsing
      if @log_configuration_file.present?
        begin
          Log4r::Configurator.load_xml_file(@log_configuration_file)
        rescue StandardError => e
          puts "error while parsing log_configuration_file: #{@log_configuration_file}: #{e.message}"
          puts "continuing ... since this is probably not fatal"
        end
      end

      if @log_level.present?
        set_logger_levels(@log_level)
      end

      if @daemon
        @log_all_output = true
      end

      if @log_all_output
        path = Pathname.new(@log_dir.to_s)
        path.mkpath
        if @log_file.present?
          log_path =  @log_file
        else
          log_path =  path + "#{@log_file_basename}#{@log_file_extension}"
        end
        $stdout.reopen(log_path, "a")
        $stderr.reopen(log_path, "a")
        $stdout.sync = true
        $stderr.sync = true
      end

      if @daemon
        logger.info "Daemonizing"
        pid = fork
        if pid
          exit 0
        else
          logger.info "forked"
          Process.setsid
          trap 'SIGHUP', 'IGNORE'
          cleanup_after_fork
        end
      end
    end

    def cleanup_after_fork
      ActiveRecord::Base.connection.reconnect!
    end

    module Proxy
      def af_logger(logger_name = (af_name || "Unknown"))
        return ::Af::Application.singleton.logger(logger_name)
      end

      def af_name
        return ::Af::Application.singleton.af_name
      end
    end

    module SafeProxy
      def af_logger(logger_name = (af_name || "Unknown"))
        return ::Af::Application.singleton(true).logger(logger_name)
      end

      def af_name
        return ::Af::Application.singleton(true).af_name
      end
    end
  end
end
