module ::Af::OptionParser
  class OptionGroup
    FACTORY_SETTABLES = [:title, :priority, :description, :hidden, :disabled]
    attr_accessor *FACTORY_SETTABLES
    attr_accessor :group_name

    @@option_groups = {}

    def self.option_groups
      return @@option_groups.reject{|k,v| v.disabled}
    end

    def initialize(group_name, parameters = {})
      @group_name = group_name
      set_instance_variables(parameters)
      @@option_groups[group_name] = self
    end

    def self.find(group_name)
      return option_groups[group_name]
    end

    def set_instance_variables(parameters = {})
      parameters.select do |name,value|
        FACTORY_SETTABLES.include? name
      end.each do |name,value|
        instance_variable_set("@#{name}", value)
      end
    end

    def self.factory(group_name, factory_hash = {})
      option_group = find(group_name) || new(group_name)
      option_group.set_instance_variables(factory_hash)
      return option_group
    end
  end
end
