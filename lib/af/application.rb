require 'log4r'
require 'log4r/configurator'
require 'log4r/yamlconfigurator'
require 'log4r/outputter/consoleoutputters'
require 'log4r_remote_syslog_outputter'
require 'pg_advisory_locker'
require 'pg_application_name'
require 'reasonable_log4r'

module Af

  # Abstract superclass for implementing command line applications.
  #
  # Provides:
  #   * Command line option parsing.
  #   * Logging with Log4r.
  #   * Pre and post option processes hooks.
  #   * Proxy support access to application frame functionality from other classes
  #
  # Subclasses must implement:
  #   * work
  #
  # Subclasses can implement:
  #   * pre_work
  #
  # Advanced Subclasses may implement:
  #   * post_command_line_parsing
  #   * option_handler
  #   * ??
  #
  class Application < ::Af::CommandLiner

    # Default set of option groups and options.
    opt_group :logging, "logger options", :priority => 100, :hidden => true, :description => <<-DESCRIPTION
      These are options associated with logging whose core is Log4r.
      Logging files should be in yaml format and should probably define a logger for 'Af' and 'Process'.
    DESCRIPTION

    opt_group :debugging, "debugging options", :priority => 1000, :hidden => true, :description => <<-DESCRIPTION
      These are options associated with debugging the internal workings of the Af::Application sysyem and ruby
      in general.
    DESCRIPTION

    opt :daemon, "run as daemon", :short => :d
    opt :log_configuration_files, "a list of yaml files for log4r to use as configurations", :type => :strings, :default => ["af.yml"], :group => :logging
    opt :log_configuration_search_path, "directories to search for log4r files", :type => :strings, :default => ["."], :group => :logging
    opt :log_configuration_section_names, "section names in yaml files for log4r configurations", :type => :strings, :default => ["log4r_config"], :env => 'LOG_CONFIGURATION_SECTION_NAMES', :group => :logging
    opt :log_dump_configuration, "show the log4r configuration", :group => :logging
    opt :log_levels, "set log levels", :type => :hash, :group => :logging
    opt :log_stdout, "set logfile for stdout (when daemonized)", :type => :string, :group => :logging
    opt :log_stderr, "set logfile for stderr (when daemonized)", :type => :string, :group => :logging
    opt :log_console, "force logging to console", :group => :logging
    opt :gc_profiler, "enable the gc profiler", :group => :debugging
    opt :gc_profiler_interval_minutes, "number of minutes between dumping gc information", :default => 60, :argument_note => "MINUTES", :group => :debugging

    attr_accessor :has_errors, :daemon

    @@singleton = nil

    # Return the single allowable instance of this class.
    #
    # *Arguments*
    #   * safe - defaults to false, instantiates instance if it doesn't exist
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

    # TODO AK: What happens if this is called multiple times? It's not guarenteed
    # to only return the singleton object, right?
    def initialize
      super
      @@singleton = self
      set_connection_application_name(startup_database_application_name)
      $stdout.sync = true
      $stderr.sync = true
      update_opts :log_configuration_search_path, :default => [".", Rails.root + "config/logging"]
      update_opts :log_configuration_files, :default => ["af.yml", "#{af_name}.yml"]
      update_opts :log_stdout, :default => Rails.root + "log/runner.log"
      update_opts :log_stderr, :default => Rails.root + "log/runner-errors.log"
    end

    # Set the application name on the ActiveRecord connection. It is
    # truncated to 64 characters.
    #
    # *Arguments*
    #   * name - application name to set on the connection
    def set_connection_application_name(name)
      ActiveRecord::ConnectionAdapters::ConnectionPool.initialize_connection_application_name(name[0...63])
    end

    # Application name consisting of process PID and af name.
    def startup_database_application_name
      return "//pid=#{Process.pid}/#{af_name}"
    end

    # Accessor for the application name set on the ActiveRecord database connection.
    def database_application_name
      return self.class.startup_database_application_name
    end

    # Accessor for the af name set on the instance's class.
    #
    # TODO AK: Where is "name" set? Does the subclass need to implement it?
    def af_name
      return self.class.name
    end

    # Returns the logger with the provided name, instantiating it if needed.
    #
    # *Arguments*
    #   * logger_name - logger to return, defaults to ":default"
    def logger(logger_name = :default)
      # Coerce the logger_name if needed.
      logger_name = af_name if logger_name == :default
      # Check with Log4r to see if there is a logger by this name.
      # If Log4r doesn't have a logger by this name, make one with Af defaults.
      return Log4r::Logger[logger_name] || Log4r::Logger.new(logger_name)
    end

    # Run this application with the provided arguments that must adhere to
    # configured command line switches.  It rewrites ARGV with these values.
    #
    # *Example*
    #   instance._run("-v", "--file", "foo.log")
    #
    # *Arguments*
    #   * arguments - list of command line option strings
    #
    # TODO AK: I still don't love that we have to rewrite ARGV to call
    # applications within Ruby.  I would prefer it if passing a hash of
    # arguments prevented the use of Getoptlong and the args hash was
    # processed according to the configred switches.
    # TODO AK: Can we rename this to "run_with_arguments"?
    def self._run(*arguments)
      # this ARGV hack is here for test specs to add script arguments
      ARGV[0..-1] = arguments if arguments.length > 0
      self.new._run
    end

    # Run the application, fetching and parsing options from the command
    # line.
    #
    # *Arguments*
    #   * usage - string describing usage (optional)
    #   * options - hash of options, containing ???
    #
    # TODO AK: Instead of prefixing this with an underscore, can't it just
    # be protected? I assume the underscore indicates that it's not part of
    # the public interface?
    def _run(usage = nil, options = {})
      @options = options
      @usage = usage || "rails runner #{self.class.name}.run [OPTIONS]"

      command_line_options(@options, @usage)

      post_command_line_parsing

      pre_work

      return self
    end

    # Execute the actual work of the application upon execution.
    #
    # this method is used to wrap the actual run code with
    # whatever specific code we are looking to maintain the
    # execution context.
    #
    # one can imagine overlaoding this function with something
    # call initiates a profiler or debugger
    #
    def _work
      begin
        work
      rescue SystemExit
        # we do nothing here
      rescue Exception => e
        # catching Exception cause some programs and libraries suck
        logger.error "fatal error durring work: #{e.message}"
        logger.fatal e
        @has_errors = true
        # TODO AK: Can't we just re-raise e and put the call to "exit" in
        # an "ensure" block? Or does that not make a difference?
      end

      if @gc_profiler
        logger("GC::Profiler").info GC::Profiler.result
      end

      exit @has_errors ? 1 : 0
    end

    def work
      raise NotImplemented.new("#{self.class.name}#work must be implemented to use the Application framework")
    end

    # Instantiate and run the application.
    #
    # *Arguments*
    #   - arguments - ????
    def self.run(*arguments)
      application = self.new._run(*arguments)
      application._work
    end

    protected

    # TODO AK: Is this like a method missing for option parsing?  Some
    # comments describing it's purpose would be helpful.
    def option_handler(option, argument)
    end

    # Overload to do any command line parsing.
    # Call exit if needed.  Always call super.
    def post_command_line_parsing
    end

    # Load the provided yaml Log4r configuration files.
    #
    # *Arguments*
    #   * files - array of file names with full paths (??)
    #   * yaml_sections - ???
    def logging_load_configuration_files(files, yaml_sections)
      begin
        Log4r::YamlConfigurator.load_yaml_files(files, yaml_sections)
      rescue StandardError => e
        puts "error while parsing log configuration files: #{e.message}"
        puts "continuing without your configuration"
        puts e.backtrace.join("\n")
        return false
      end
      return true
    end

    # Load all of the Log4r yaml configuration files.
    # TODO AK: Where is "@log_configuration_files" and
    # "@log_configuration_search_path" set?
    def logging_load_configuration
      files = []
      @log_configuration_files.each do |configuration_file|
        @log_configuration_search_path.each do |path|
          pathname = Pathname.new(path) + configuration_file
          files << pathname.to_s if pathname.file?
        end
      end
      logging_load_configuration_files(files, @log_configuration_section_names)
    end

    # TODO AK: What is purpose of this method?
    def logging_configuration_looks_bogus
      return Log4r::LNAMES.length == 1
    end

    # Overload to do any operations that need to be handled before work is called.
    # Call exit if needed. Always call super.
    def pre_work
      if log_console
        Log4r::Configurator.custom_levels(:DEBUG, :DEBUG_FINE, :DEBUG_MEDIUM, :DEBUG_GROSS, :DETAIL, :INFO, :WARN, :ALARM, :ERROR, :FATAL)
        Log4r::Logger.root.outputters << Log4r::Outputter.stdout
      else
        logging_load_configuration
        if logging_configuration_looks_bogus
          Log4r::Configurator.custom_levels(:DEBUG, :DEBUG_FINE, :DEBUG_MEDIUM, :DEBUG_GROSS, :DETAIL, :INFO, :WARN, :ALARM, :ERROR, :FATAL)
          Log4r::Logger.root.outputters << Log4r::Outputter.stdout
        end
      end

      if @log_levels
        set_logger_levels(log_levels)
      end

      if @log_dump_configuration
        puts "Log configuration search path:" 
        puts " " + @log_configuration_search_path.join("\n ")
        puts "Log configuration files:"
        puts " " + @log_configuration_files.join("\n ")
        puts "Logging Names: #{Log4r::LNAMES.join(', ')}"
        puts "Yaml section names:"
        puts " " + @log_configuration_section_names.join("\n ")
        loggers = []
        Log4r::Logger.each do |logger_name, logger|
          loggers << logger_name
        end
        puts "Loggers:"
        puts "global: #{Log4r::LNAMES[Log4r::Logger.global.level]}"
        puts "root: #{Log4r::LNAMES[Log4r::Logger['root'].level]} [#{Log4r::Logger['root'].outputters.map{|o| o.name}.join(', ')}]"
        loggers.sort.reject{|logger_name| ["root", "global"].include? logger_name}.each do |logger_name|
          puts "#{' ' * logger_name.split('::').length}#{logger_name}: #{Log4r::LNAMES[Log4r::Logger[logger_name].level]} [#{Log4r::Logger[logger_name].outputters.map{|o| o.name}.join(', ')}]"
        end
        exit 0
      end

      if @gc_profiler
        logger("GC::Profiler").info "Enabling GC:Profilier"
        logger("GC::Profiler").info "Signal USR1 will dump results"
        logger("GC::Profiler").info "Will dump every #{@gc_profiler_interval_minutes} minutes"
        GC::Profiler.enable
        @last_gc_profiler_dump = Time.zone.now
        Signal.trap("USR1") do
          logger("GC::Profiler").info GC::Profiler.result
        end
      end

      if @daemon
        $stdout.reopen(@log_stdout, "a")
        $stderr.reopen(@log_stderr, "a")
        $stdout.sync = true
        $stderr.sync = true
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

    # Parse and return the provided log level, which can be an integer,
    # string integer or string constant.  Returns all loging levels if value
    # cannot be parsed.
    #
    # *Arguments*
    #   * logger_level - log level to be parsed
    #
    # TODO AK: Declaring a class method with "self.method_name" after declaring
    # "protected" doesn't change the method's visibility.  If has to be defined
    # using "class << self".
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

    # Parses and sets the provided logger levels.
    #
    # *Argument*
    #   * logger_info - value indicating default log level, or JSON string
    #     of logger names to logger levels, i.e. "{'foo' => 'INFO'}.
    def parse_and_set_logger_levels(logger_info)
      log_level_hash = JSON.parse(logger_info) rescue {:default => self.class.parse_log_level(logger_info)}
      set_logger_levels(log_level_hash)
    end

    # Sets the logger levels the provided hash.  It supports the following formats for
    # logger levels: 1, "1", "INFO", "Log4r::INFO".
    #
    # *Arguments*
    #   * log_level_hash - hash of logger names to logger levels,
    #     i.e. { :foo => 'INFO' }
    def set_logger_levels(log_level_hash)
      log_level_hash.map { |logger_name, logger_level|
        logger_name = :default if logger_name == "default"
        logger_level_value = self.class.parse_log_level(logger_level)
        l = logger(logger_name)
        l.level = logger_level_value
      }
    end

    # Returns a list of OS signals.
    def signal_list
      return Signal.list.keys
    end

    # Utility method to wrap code in a protective sheen
    # use with "signal_list"
    def protect_from_signals
      # we are indiscriminate with the signals we block -- too bad ruby doesn't have some
      # reasonable signal management system
      signals = Hash[signal_list.map {|signal| [signal, Signal.trap(signal, "IGNORE")] }]
      begin
        yield
      ensure
        signals.each {|signal, saved_value| Signal.trap(signal, saved_value)}
      end
    end

    # call this every once in a while
    def periodic_application_checkpoint
      if @gc_profiler
        if (Time.zone.now - @last_gc_profiler_dump) > @gc_profiler_interval_minutes.minutes
          @last_gc_profiler_dump = Time.zone.now
          logger("GC::Profiler").info GC::Profiler.result
        end
      end
    end

    # Proxy's are used by dependant classes to reach back to the Application frame for
    # some functionality.
    #
    # consider a model that wishes to use the logging functionality of Af:
    #
    #    class Foo < ActiveRecord::Base
    #      include ::Af::Application::SafeProxy
    #
    #      after_create :do_something_after_create
    #
    #      def foo_logger
    #        return af_logger(self.class.name)
    #      end
    #
    #      private
    #      def do_something_after_create
    #        foo_logger.info "created: #{self.inspect}"
    #      end
    #    end
    #
    # The difference between Proxy and SafeProxy is simply that
    # SafeProxy can be used in classes that may not be in an Af::Application
    # run (ie, models that are shared with a Rails web app wher Af::Application
    # is never instantiated)
    #
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
