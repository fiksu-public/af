require 'log4r'
require 'log4r/configurator'
require 'log4r/yamlconfigurator'
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
    opt :log_configuration_file, "load an log4r xml or yaml configuration file", :type => :string, :argument_note => 'FILENAME', :group => :logging

    attr_accessor :has_errors, :daemon, :log_dir, :log_file, :log_file_basebane, :log_file_extension, :log_all_output, :log_level, :log_configuration_file

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
      @logger_levels = {:default => DEFAULT_LOG_LEVEL}
      @log4r_name_suffix = ""
      ActiveRecord::ConnectionAdapters::ConnectionPool.initialize_connection_application_name(self.class.database_application_name)
      $stdout.sync = true
      $stderr.sync = true
      update_opts :log_file_basename, :default => af_name
    end

    def self.database_application_name
      # (nlim) Truncate to Postgres limit so Postgres stops yelling
      return "#{self.name}(pid: #{Process.pid})".slice(0, 63)
    end

    def af_name
      return self.class.name
    end

    def af_pattern_formatter_format
      return "%l %C %M"
    end

    # Af's default formatter 
    def af_formatter
      return Log4r::PatternFormatter.new(:pattern => af_pattern_formatter_format)
    end

    # Af's default outputters (add more if desired)
    def af_outputters
      [af_stdout_outputter]
    end

    # Af's default STDOUT outputter
    def af_stdout_outputter
      if Log4r::Outputter["stdout"].blank?
        return Log4r::StdoutOutputter.new("stdout", :formatter => af_formatter)
      else
        return Log4r::Outputter["stdout"]
      end
    end

    # Now allows for the Log4r convention of having
    # multiple outputters per logger to be visible through Af's interface.
    def log4r_outputters(logger_name = :default)
      logger(logger_name).outputters
    end

    def logger_level(logger_name = :default)
      logger_name = :default if logger_name == af_name
      return @logger_levels[logger_name] || DEFAULT_LOG_LEVEL
    end

    # (nlim) TODO: Remove if not needed
    # This method is not being used currently 
    def set_logger_level(new_logger_level, logger_name = :default)
      logger_name = :default if logger_name == af_name
      @logger_level[logger_name] = new_logger_level
    end

    # (nlim) Getting the logger requires testing to see
    # if Log4r has it defined, and then if Af has it defined
    # in the @loggers hash
    # 
    # Changes here allow for Af to use loggers
    # of Log4r::Logger instantiations already configured
    # via a configuration file, and if it doesn't exist
    # make one with Af defaults and the command-line specified
    # logger level.
    def logger(logger_name = :default)
      # Coerce the logger_name if needed
      logger_name = :default if logger_name == af_name
      # Translate  Af logger names to Log4r logger names
      log4r_logger_name =  logger_name == :default ? af_name : "#{af_name}::#{logger_name}"
      # Check with Log4r to see if there is a logger by this name
      # If Log4r doesn't have a logger by this name, make one with Af defaults
      log4r_logger = Log4r::Logger[log4r_logger_name]
      if log4r_logger.blank?
        log4r_logger = Log4r::Logger.new(log4r_logger_name)
        log4r_logger.outputters = af_outputters
        log4r_logger.level = logger_level(logger_name)
        log4r_logger.additive = false # No logging to ancesters
      end
      # Set the entry in @loggers hash if it's not defined
      @loggers[logger_name] = log4r_logger unless @loggers.has_key?(logger_name)
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

    def set_logger_levels(log_level_hash)
      # (nlim) We really shouldn't log anything until the log level is set.
      # logger.info "set_logger_levels: #{log_level_hash.map{|k,v| k.to_s + '=>' + v.to_s}.join(',')}"
      logger_level_value = DEFAULT_LOG_LEVEL
      # Fix the overriding of default, and the checking of constantizing the arguments
      coerced_log_level_hash = log_level_hash.keys.each_with_object({}) { |logger_name, hash|
        logger_level = log_level_hash[logger_name]
        begin
          logger_level_value = logger_level.constantize
        rescue StandardError => e
          logger.error "invalid log level value: #{logger_level} for logger: #{logger_name}, using Log4r::ALL = 0"
        end
        # Use symbol :default for the Af logger, otherwise, use a string for the key
        hash[logger_name == "default" ? :default : logger_name] = logger_level_value
      }
      @logger_levels.merge!(coerced_log_level_hash)
      @logger_levels.each do |logger_name, logger_level|
        # Get or create the logger by name
        l = logger(logger_name)
        # Make sure the level is overridden
        l.level = logger_level_value
        logger.detail "set_logger_levels: #{logger_name} => #{logger_level_value}"
      end
    end

    def post_command_line_parsing
      if @log_configuration_file.present?
        begin
          puts "Configuring with file"
          # Use different configurator methods based on the file extension
          case @log_configuration_file.split('.').last.downcase.to_sym
          when :xml
            Log4r::Configurator.load_xml_file(@log_configuration_file)
          when :yml
            puts "a YAML file"
            Log4r::YamlConfigurator.decode_yaml(YAML.load_file(@log_configuration_file))
          else
            puts "NOTICE: Configuration failed: Not a .xml or .yml file."
          end
        rescue StandardError => e
          puts "error while parsing log_configuration_file: #{@log_configuration_file}: #{e.message}"
          puts "continuing without your configuration"
        end
      end

      if @log_level.present?
        set_logger_levels(@log_level)
      end

      Log4r::Logger.each do |logger|
        puts logger.inspect
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
      def af_logger(logger_name = (self.try(:af_name) || "Unknown"))
        return ::Af::Application.singleton.logger(logger_name)
      end

      def af_name
        return ::Af::Application.singleton.af_name
      end
    end

    module SafeProxy
      def af_logger(logger_name = (self.try(:af_name) || "Unknown"))
        return ::Af::Application.singleton(true).logger(logger_name)
      end

      def af_name
        return ::Af::Application.singleton(true).af_name
      end
    end
  end
end
