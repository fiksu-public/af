require 'pg_advisory_locker'
require 'pg_application_name'

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
  class Application
    include Af::OptionParser
    include Af::Logging
    include Af::Deprecated

    ### Command Line Options ###

    # A number of default command line switches and switch groups available to all
    # subclasses.

    opt_group :basic, "basic options", :priority => 0, :description => <<-DESCRIPTION
      These are the stanadard options offered to all Af commands.
    DESCRIPTION

    opt_group :basic do
      opt '?', "show this help (--?? for all)", :short => '?', :var => nil do
        Helper.new(::Af::Application.singleton.af_opt_class_path).help(::Af::Application.singleton.usage)
        exit 0
      end
      opt '??', "show help for all commands", :hidden => true, :var => nil do
        Helper.new(::Af::Application.singleton.af_opt_class_path).help(::Af::Application.singleton.usage, true)
        exit 0
      end
      opt :daemon, "run as daemon", :short => :d
    end

    opt_group :advanced, "advanced options", :priority => 100, :hidden => true, :description => <<-DESCRIPTION
      These are advanced options offered to this programs.
    DESCRIPTION

    opt_group :debugging, "debugging options", :priority => 1000, :hidden => true, :description => <<-DESCRIPTION
      These are options associated with debugging the internal workings of the Af::Application sysyem and ruby
      in general.
    DESCRIPTION

    opt_group :debugging do
      opt :gc_profiler, "enable the gc profiler"
      opt :gc_profiler_interval_minutes, "number of minutes between dumping gc information", :default => 60, :argument_note => "MINUTES"
    end

    opt_group :logging, "logger options", :priority => 100, :hidden => true, :description => <<-DESCRIPTION
      These are options associated with logging whose core is Log4r.
      Logging files should be in yaml format and should probably define a logger for 'Af' and 'Process'.
    DESCRIPTION
    
    opt_group :logging, :target_container => Af::Logging::Configurator do
      opt :log_configuration_files, "a list of yaml files for log4r to use as configurations", :type => :strings, :default => ["af.yml"]
      opt :log_configuration_search_path, "directories to search for log4r files", :type => :strings, :default => ["."]
      opt :log_configuration_section_names, "section names in yaml files for log4r configurations", :type => :strings, :default => ["log4r_config"], :env => 'LOG_CONFIGURATION_SECTION_NAMES'
      opt :log_dump_configuration, "show the log4r configuration"
      opt :log_levels, "set log levels", :type => :hash
      opt :log_stdout, "set logfile for stdout (when daemonized)", :type => :string
      opt :log_stderr, "set logfile for stderr (when daemonized)", :type => :string
      opt :log_console, "force logging to console"
      opt :log_ignore_configuration, "ignore logging configuration files", :default => false
    end

    ### Attributes ###

    attr_accessor :has_errors

    @@singleton = nil

    ### Class methods ###

    # Instantiate and run the application.
    #
    # *Arguments*
    #   - arguments - ????
    def self.run(*arguments)
      application = self.new._run(*arguments)
      application._work
    end

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

    ### Instance Methods ###

    # Run the application, fetching and parsing options from the command
    # line.
    #
    # *Arguments*
    #   * usage - string describing usage (optional)
    #   * options - hash of options, containing ???
    def _run
      process_command_line_options(af_opt_class_path)
      post_command_line_parsing
      pre_work
      return self
    end

    # Execute the actual work of the application upon execution.
    #
    # This method is used to wrap the actual run code with
    # whatever specific code we are looking to maintain the
    # execution context.
    #
    # one can imagine overlaoding this function with something
    # call initiates a profiler or debugger
    def _work
      begin
        work
      rescue SystemExit => se
        # we do nothing here
        if se.status != 0
          logger.error "exit called with error: #{se.message}"
          logger.fatal se
          exit se.status
        end
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

    # Accessor for the af name set on the instance's class.
    def af_name
      return self.class.name
    end

    # override if you wish to include other class's opt/opt_group
    def af_opt_class_path
      return [self.class]
    end

    protected

    # TODO AK: What happens if this is called multiple times? It's not guarenteed
    # to only return the singleton object, right?
    def initialize
      super
      @@singleton = self
      set_connection_application_name(startup_database_application_name)
      $stdout.sync = true
      $stderr.sync = true
      opt :log_configuration_search_path, :default => [".", Rails.root + "config/logging"]
      opt :log_configuration_files, :default => ["af.yml", "#{af_name}.yml"]
      opt :log_stdout, :default => Rails.root + "log/runner.log"
      opt :log_stderr, :default => Rails.root + "log/runner-errors.log"
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

    # Work performed by this application.  MUST be implemented by subclasses.
    def work
      raise NotImplemented.new("#{self.class.name}#work must be implemented to use the Application framework")
    end

    # Overload to do any command line parsing.
    # Call exit if needed.  Always call super.
    def post_command_line_parsing
    end

    # Overload to do any operations that need to be handled before work is called.
    # Call exit if needed. Always call super.
    def pre_work
      logging_configurator.configurate

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
        $stdout.reopen(Af::Logging::Configurator.log_stdout, "a")
        $stderr.reopen(Af::Logging::Configurator.log_stderr, "a")
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
    # run (ie, models that are shared with a Rails web app where Af::Application
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
