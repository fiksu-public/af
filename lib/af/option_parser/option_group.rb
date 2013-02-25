module ::Af::OptionParser
  class OptionGroup
    attr_accessor :group_name, :title, :priority, :description

    @@option_groups = {}

    def self.option_groups
      return @@option_groups
    end

    def initialize(group_name, title = nil, description = nil, priority = nil)
      @group_name = group_name
      @title = title
      @description = description
      @priority = priority
      @options = Set.new
      @@option_groups[group_name] = self
    end

    def add_options(option_long_name)
      @options << option_name.to_s
    end

    def self.find(group_name)
      return option_groups.find{|group_name_key,group_option_value|
        group_option_value.group_name == group_name
      }
    end

    def self.factory(group_name, title = nil, priority = nil, description = nil)
      option_group = find(group_name) || new(group_name)
      option_group.title = title if title
      option_group.priority = priority if priority
      option_group.description = description if description
      return option_group
    end
  end
end
