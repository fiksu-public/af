module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool
      @connection_application_name = "unknown af process"

      def self.connection_application_name=(value)
        return @connection_application_name = value
      end

      def self.connection_application_name
        return @connection_application_name
      end

      def self.sql_for_set_application_name(application_name)
        name = application_name.gsub(/'/, "''")
        return "set application_name = '#{name}'"
      end

      def self.initialize_connection_application_name(application_name)
        self.connection_application_name = application_name
        ActiveRecord::Base.connection.execute(self.sql_for_set_application_name(application_name))
      end

      private
      def new_connection_with_set_application_name
        c = new_connection_without_set_application_name
        c.execute(self.class.sql_for_set_application_name(self.class.connection_application_name))
        c
      end
      alias_method_chain :new_connection, :set_application_name
    end
  end
end
