require 'log4r'
require 'log4r/configurator'
require 'log4r/yamlconfigurator'
require 'log4r_remote_syslog_outputter'
require 'pg_advisory_locker'
require 'pg_application_name'

module Af
  class Application < ::Af::CommandLiner
    opt_group :logging, "logger options", :priority => 100, :hidden => true, :description => <<-DESCRIPTION
      These are options associated with logging whose core is Log4r.  Current log levels are:
       Log4r::#{Log4r::LNAMES.join(', Log4r::')}
      Logging files should be in yaml format and should probably define a logger for 'Af' and 'Process'.
    DESCRIPTION

    opt :daemon, "run as daemon", :short => :d
    opt :log_configuration, "file or directory for log4r configurator", :type => :string, :group => :logging
    opt :log_dump_configuration, "show the log4r configuration", :group => :logging

    attr_accessor :has_errors, :daemon

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

      set_connection_application_name(startup_database_application_name)
      $stdout.sync = true
      $stderr.sync = true
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
    end

    def logging_load_configuration_file(path)
      begin
        Log4r::YamlConfigurator.load_yaml_file(path.to_s)
      rescue StandardError => e
        puts "error while parsing log_configuration_file: #{path}: #{e.message}"
        puts "continuing without your configuration"
        puts e.backtrace.join("\n")
        return false
      end
      return true
    end

    def logging_load_configuration(pathname, application_filename = "#{af_name}.yml", general_filename = "logging.yml")
      path = Pathname.new(pathname)
      if path.directory?
        application_file_path = path + application_filename
        if application_file_path.file?
          return logging_load_configuration_file(application_file_path)
        end
        general_file_path = path + general_filename
        if general_file_path.file?
          return logging_load_configuration_file(general_file_path)
        end
      else
        return logging_load_configuration_file(path)
      end
    end

    # Overload to do any operations that need to be handled before work is called.
    # call exit if needed.  always call super
    def pre_work
      # load log4r configuration files
      logging_configured = false
      if @log_configuration.present?
        logging_configured = logging_load_configuration(@log_configuration)
      end

      if @log_dump_configuration
        puts "logging_configured: #{logging_configured}"
        Log4r::Logger.each_logger do |logger|
          puts logger.inspect
        end
        exit 0
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
      }
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
