require 'log4r/logger'
require 'log4r/yamlconfigurator'

module Log4r
  class RootLogger < Logger
    def initialize
      Log4r.define_levels(*Log4rConfig::LogLevels) # ensure levels are loaded
      @level = ALL
      @outputters = []
      Repository['root'] = self
      LoggerFactory.define_methods(self)
    end

    def is_root?; true end

    # Set the global level. Any loggers defined thereafter will
    # not log below the global level regardless of their levels.

    def level=(alevel); @level = alevel end

    # Does nothing
    def additive=(foo); end

    def outputters=(foo)
      super
    end
    def trace=(foo)
      super
    end
    def add(*foo)
      super
    end
    def remove(*foo)
      super
    end
  end

  class GlobalLogger < Logger
    include Singleton

    def initialize
      Log4r.define_levels(*Log4rConfig::LogLevels) # ensure levels are loaded
      @level = ALL
      @outputters = []
      Repository['global'] = self
      LoggerFactory.undefine_methods(self)
    end

    def is_root?; true end

    # Set the global level. Any loggers defined thereafter will
    # not log below the global level regardless of their levels.

    def level=(alevel); @level = alevel end

    # Does nothing
    def outputters=(foo); end
    # Does nothing
    def trace=(foo); end
    # Does nothing
    def additive=(foo); end
    # Does nothing
    def add(*foo); end
    # Does nothing
    def remove(*foo); end
  end

  class Logger
    # Returns the root logger. Identical to Logger.global
    def self.root; return RootLogger.instance end
    # Returns the root logger. Identical to Logger.root
    def self.global; return GlobalLogger.instance end
    
    # Get a logger with a fullname from the repository or nil if logger
    # wasn't found.

    def self.[](_fullname)
      # forces creation of RootLogger if it doesn't exist yet.
      if _fullname=='root'
        return RootLogger.instance
      end
      if _fullname=='global'
        return GlobalLogger.instance
      end
      Repository[_fullname]
    end

    class LoggerFactory #:nodoc:
      # we want to log iff root.lev <= lev && logger.lev <= lev
      # BTW, root is guaranteed to be defined by this point
      def self.define_methods(logger)
        undefine_methods(logger)
        globlev = Log4r::Logger['global'].level
        return if logger.level == OFF or globlev == OFF
        toggle_methods(globlev, logger)
      end

      # Logger logging methods are defined here.
      def self.set_log(logger, lname) 
        # invoke caller iff the logger invoked is tracing
        tracercall = (logger.trace ? "caller" : "nil")
        # maybe pass parent a logevent. second arg is the switch
        if logger.additive && !logger.is_root?
          parentcall = "@parent.#{lname.downcase}(event, true)"
        end
        mstr = %-
          def logger.#{lname.downcase}(data=nil, propagated=false)
            if propagated then event = data
            else
              data = yield if block_given?
              event = LogEvent.new(#{lname}, self, #{tracercall}, data)
            end
            @outputters.each {|o| o.#{lname.downcase}(event) }
            #{parentcall}
          end
        -
        module_eval mstr
      end
    end
  end

  class YamlConfigurator
    # Given a filename, loads the YAML configuration for Log4r.
    def self.load_yaml_files(filenames, yaml_sections = ['log4r_config'])
      cfgs = []
      yaml_sections.each do |yaml_section|
        filenames.each do |filename|
          log4r_config = nil
          docs = File.open(filename)
          begin
            YAML.load_documents(docs) do |doc|
              doc.has_key?(yaml_section) and log4r_config = doc[yaml_section] and break
            end
          rescue Exception => e
            raise "YAML error, file: #{filename}, error=#{e.message}"
          end
          if log4r_config
            cfgs << log4r_config
          end
        end
      end

      cfgs.each do |cfg|
        decode_pre_config(cfg['pre_config']) unless cfg['pre_config'].nil?
      end

      cfgs.each do |cfg|
        cfg['outputters'].each{ |op| decode_outputter(op)} unless cfg['outputters'].nil?
      end

      cfgs.each do |cfg|
        cfg['loggers'].each{ |lo| decode_logger(lo)} unless cfg['loggers'].nil?
      end

      cfgs.each do |cfg|
        cfg['logserver'].each{ |lo| decode_logserver(lo)} unless cfg['logserver'].nil?
      end
    end

    def self.decode_pre_config(pre)
      return Logger.root if pre.nil?
      decode_custom_levels( pre['custom_levels'])
      global_config( pre['global'])
      root_config( pre['root'])
      decode_parameters( pre['parameters'])
    end

    def self.root_config(e)
      return if e.nil?
      globlev = e['level']
      return if globlev.nil?
      lev = LNAMES.index(globlev)     # find value in LNAMES
      Log4rTools.validate_level(lev, 4)  # choke on bad level
      Logger.root.level = lev
    end

    def self.decode_logger(lo)
      if lo['name'] == 'root'
        l = Logger.root
      elsif lo['name'] == 'global'
        l = Logger.global
      else
        l = Logger.new lo['name']
      end
      decode_logger_common(l, lo)
    end
  end
end
