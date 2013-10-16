require 'log4r'
require 'log4r/configurator'
require 'log4r/yamlconfigurator'
require 'log4r/outputter/consoleoutputters'
require 'log4r_remote_syslog_outputter'
require 'reasonable_log4r'

module Af::Logging
  class Configurator
    @@singleton = nil

    # Return the single allowable instance of this class, if the class has been instantiated
    def self.singleton
      return @@singleton ||= new
    end

    def initialize
      @@singleton = self
      Log4r::Configurator.custom_levels(:DEBUG, :DEBUG_FINE, :DEBUG_MEDIUM, :DEBUG_GROSS, :DETAIL, :INFO, :WARN, :ALARM, :ERROR, :FATAL)
    end

    # Parse and return the provided log level, which can be an integer,
    # string integer or string constant.  Returns all loging levels if value
    # cannot be parsed.
    #
    # *Arguments*
    #   * logger_level - log level to be parsed
    def parse_log_level(logger_level)
      if logger_level.is_a? Integer
        logger_level_value = logger_level
      elsif logger_level.is_a? String
        if logger_level[0] =~ /[0-9]/
          logger_level_value = logger_level.to_i
        else
          logger_level_value = logger_level.constantize rescue nil
          logger_level_value = "Log4r::#{logger_level.upcase}".constantize rescue nil unless logger_level_value
        end
      else
        logger_level_value = Log4r::ALL
      end
      return logger_level_value
    end

    # Returns the logger with the provided name, instantiating it if needed.
    #
    # *Arguments*
    #   * logger_name - logger to return, defaults to ":default"
    def logger(logger_name = :default)
      # Coerce the logger_name if needed.
      logger_name = ::Af::Application.singleton.af_name if logger_name == :default
      # Check with Log4r to see if there is a logger by this name.
      # If Log4r doesn't have a logger by this name, make one with Af defaults.
      return Log4r::Logger[logger_name] || Log4r::Logger.new(logger_name)
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
    def logging_load_configuration
      files = []
      @@log_configuration_files.each do |configuration_file|
        @@log_configuration_search_path.each do |path|
          pathname = Pathname.new(path) + configuration_file
          files << pathname.to_s if pathname.file?
        end
      end
      logging_load_configuration_files(files, @@log_configuration_section_names)
    end

    # TODO AK: What is purpose of this method?
    def logging_configuration_looks_bogus
      return Log4r::LNAMES.length == 1
    end

    # Parses and sets the provided logger levels.
    #
    # *Argument*
    #   * logger_info - value indicating default log level, or JSON string
    #     of logger names to logger levels, i.e. "{'foo' => 'INFO'}.
    def parse_and_set_logger_levels(logger_info)
      log_level_hash = JSON.parse(logger_info) rescue {:default => parse_log_level(logger_info)}
      set_logger_levels(log_level_hash)
    end

    # Sets the logger levels the provided hash.  It supports the following formats for
    # logger levels: 1, "1", "INFO", "Log4r::INFO".
    #
    # *Arguments*
    #   * log_level_hash - hash of logger names to logger levels,
    #     i.e. { :foo => 'INFO' }
    def set_logger_levels(log_level_hash)
      log_level_hash.each do |logger_name, logger_level|
        logger_name = :default if logger_name == "default"
        logger_level_value = parse_log_level(logger_level)
        l = logger(logger_name)
        l.level = logger_level_value
      end
    end

    def configurate
      if (@@log_console || @@log_ignore_configuration) && !@@log_configurate
        Log4r::Logger.root.outputters << Log4r::Outputter.stdout
      else
        logging_load_configuration
        if logging_configuration_looks_bogus
          Log4r::Logger.root.outputters << Log4r::Outputter.stdout
        end
      end

      if @@log_levels
        set_logger_levels(@@log_levels)
      end

      if @@log_dump_configuration
        puts "Log configuration search path:"
        puts " " + @@log_configuration_search_path.join("\n ")
        puts "Log configuration files:"
        puts " " + @@log_configuration_files.join("\n ")
        puts "Logging Names: #{Log4r::LNAMES.join(', ')}"
        puts "Yaml section names:"
        puts " " + @@log_configuration_section_names.join("\n ")
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
    end

  end
end
