module ::Af::OptionParser
  class OptionStore
    attr_reader :options, :option_groups, :containing_class

    @@option_stores = {}

    def initialize(containing_class)
      @containing_class = containing_class
      @options = {}
      @option_groups = {}
    end

    def find_option(long_name)
      return options[long_name]
    end

    def construct_option(long_name)
      @options[long_name] ||= Option.new(long_name)
      return @options[long_name]
    end

    def get_option(long_name)
      return find_option(long_name) || construct_option(long_name)
    end

    def find_option_group(long_name)
      return option_groups[long_name]
    end

    def construct_option_group(name)
      @option_groups[name] ||= OptionGroup.new(name)
      return @option_groups[name]
    end

    def get_option_group(long_name)
      return find_option_group(long_name) || construct_option_group(long_name)
    end

    def self.find(containing_class)
      return @@option_stores[containing_class]
    end

    def self.factory(containing_class)
      @@option_stores[containing_class] ||= new(containing_class)
      return @@option_stores[containing_class]
    end
  end
end
