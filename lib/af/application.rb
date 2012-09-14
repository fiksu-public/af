require 'log4r'
require 'log4r/configurator'
require 'log4r/yamlconfigurator'
require 'log4r/outputter/consoleoutputters'
require 'log4r_remote_syslog_outputter'

Log4r::Configurator.custom_levels(:DEBUG, :DEBUG_FINE, :DEBUG_MEDIUM, :DEBUG_GROSS, :DETAIL, :INFO, :WARN, :ALARM, :ERROR, :FATAL)

module Af
  class Application < ::Af::CommandLiner
    opt_group :logging, "logger options", :priority => 100, :hidden => true, :description => <<-DESCRIPTION
      These are options associated with logging. By default, file logging is turned on when
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
    opt :log_configuration, "file or directory for log4r configurator", :group => :logging
    opt :log_level, "set the levels of one or more loggers", :type => :hash, :env => "AF_LOG_LEVEL", :group => :logging
    opt :log_with_timestamps, "add timestamps to log output", :env => "AF_LOG_WITH_TIMESTAMPS", :group => :logging
    opt :log_default_level, "default logger level", :default => "ALL", :group => :logging

    attr_accessor :has_errors, :daemon, :log_level, :log_configuration
    attr_accessor :log_with_timestamps, :af_outputters, :af_formatter
    attr_accessor :af_pattern_formatter_format_prefix, :af_pattern_formatter_format_logger_name, :af_pattern_formatter_format_base, :af_pattern_formatter_format_sufix

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

      @af_pattern_formatter_format_prefix = ""
      @af_pattern_formatter_format_logger_name = "//pid=#{Process.pid}/%C/%l"
      @af_pattern_formatter_format_base = " %M"
      @af_pattern_formatter_format_sufix = ""

      @af_outputters = []

      @af_formatter = nil

      @log_default_level = Log4r::ALL
      set_connection_application_name(startup_database_application_name)
      $stdout.sync = true
      $stderr.sync = true
      update_opts :log_file_basename, :default => af_name
      update_opts :log_configuration, :default => Rails.root + "/config/logging"
    end

    def set_connection_application_name(name)
      ActiveRecord::ConnectionAdapters::ConnectionPool.initialize_connection_application_name(name[0...63])
    end

    def startup_database_application_name
      return "//pid=#{Process.pid}/#{af_name}"
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

    # Af's default pattern
    def af_pattern_formatter_format
      return "#{af_pattern_formatter_format_prefix}#{af_pattern_formatter_format_logger_name}#{af_pattern_formatter_format_base}#{af_pattern_formatter_format_sufix}"
    end

    def logger(logger_name = :default)
      # Coerce the logger_name if needed
      logger_name = af_name if logger_name == :default
      # Check with Log4r to see if there is a logger by this name
      # If Log4r doesn't have a logger by this name, make one with Af defaults
      return Log4r::Logger[logger_name] || Log4r::Logger.new(logger_name)
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

    # Overload to do any any command line parsing
    # call exit if needed.  always call super
    def post_command_line_parsing
      @log_default_level = self.class.parse_log_level(@log_default_level)

      # create formatter
      if @log_with_timestamps
        @af_pattern_formatter_format_prefix = "%d "
      end

      @af_formatter = Log4r::PatternFormatter.new(:pattern => af_pattern_formatter_format, :date_pattern => "%Y-%m-%d %H:%M:%S.%L")
    end

    def logging_is_configured?
      return Log4r::Logger['Af'].present? || Log4r::Logger['Process'].present?
    end

    def load_log_configuration_file(path)
      begin
        # Use different configurator methods based on the file extension
        case path.extname.downcase.to_sym
        when :xml
          Log4r::Configurator.load_xml_file(path)
        when :yml
          Log4r::YamlConfigurator.decode_yaml(YAML.load_file(path))
        else
          puts "NOTICE: Configuration failed #{path}: Not a .xml or .yml file."
        end
      rescue StandardError => e
        puts "error while parsing log_configuration_file: #{path}: #{e.message}"
        puts "continuing without your configuration"
      end
    end

    # Overload to do any operations that need to be handled before work is called.
    # call exit if needed.  always call super
    def pre_work
      # load log4r configuration files
      if @log_configuration.present?
        path = Pathname.new(@log_configuration)
        if path.directory?
          path.children(true).sort.each do |child_path|
            if child_path.directory?
              dir, base = pn.split
              if base.split('-').last == Rails.env
                child_path.children.sort.each do |grandchild_path|
                  load_log_configuration_file(grandchild_path)
                end
              end
            else
              load_log_configuration_file(child_path)
            end
          end
        else
          load_log_configuration_file(path)
        end
      end

      # set log levels
      if @log_level.present?
        set_logger_levels(@log_level)
      end

      unless logging_is_configured?
        Log4r::Outputter.stdout.formatter = @af_formatter
        unless Log4r::Logger['Af']
          Log4r::Logger.new('Af').outputter << Log4r::Outputter.stdout
        end
        unless Log4r::Logger['Process']
          Log4r::Logger.new('Process').outputter << Log4r::Outputter.stdout
        end
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

    def add_papertrail_outputter
      outputter = Log4r::Outputter["papertrail"] 
      unless outputter
        outputter = Log4r::RemoteSyslogOutputter.new("papertrail", :url => "syslog://logs.papertrailapp.com:#{@papertrail_port}", :program => "Af")
        outputter.formatter = af_formatter
      end
      af_outputters << outputter unless af_outputters.include?(outputter)
    end

    def logger_logger
      return logger("Log4r")
    end

    def self.parse_log_level(logger_level)
      if logger_level.is_a? Integer
        logger_level_value = logger_level
      elsif logger_level.is_a? String
        if logger_level[0] =~ /[0-9]/
          logger_level_value = logger_level.to_i
        else
          logger_level_value = logger_level.constantize rescue nil
          logger_level_value = "Log4r::#{logger_level}".constantize rescue nil unless logger_level_value
        end
      else
        logger_level_value = Log4r::ALL
      end
      return logger_level_value
    end

    def parse_and_set_logger_levels(logger_info)
      log_level_hash = JSON.parse(logger_info) rescue {:default => self.class.parse_log_level(logger_info)}
      set_logger_levels(log_level_hash)
    end

    def set_logger_levels(log_level_hash)
      logger_logger.debug_gross "set_logger_levels: #{log_level_hash.map{|k,v| k.to_s + ' => ' + v.to_s}.join(', ')}"
      # we need to handle the follow cases:
      #  "x" => 1
      #  "x" => "1"
      #  "x" => "INFO"
      #  "x" => "Log4r::INFO"
      log_level_hash.map { |logger_name, logger_level|
        logger_name = :default if logger_name == "default"
        logger_level_value = self.class.parse_log_level(logger_level)
        l = logger(logger_name)
        l.level = logger_level_value
        logger_logger.detail "setting logger level: #{logger_name} => #{log4r_logger_name(logger_level_value)}"
      }

      logger_logger.debug_fine "all loggers:"
      Log4r::Logger.each() do |logger_name, logger_obj|
        logger_logger.debug_fine "logger: #{logger_name}: #{logger_obj.inspect}"
      end
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
