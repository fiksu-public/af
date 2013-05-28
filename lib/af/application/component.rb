module Af
  class Application
    # Proxy's are used by dependant classes to interact with the Application framework
    #
    # consider a model that wishes to use the logging functionality of Af:
    #
    #    class Foo < ActiveRecord::Base
    #      include ::Af::Application::Component
    #
    #      after_create :do_something_after_create
    #
    #      create_proxy_logger :foo
    #
    #      private
    #      def do_something_after_create
    #        foo_logger.info "created: #{self.inspect}"
    #      end
    #    end
    #
    module Component
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, ::Af::Logging)
      end

      module ClassMethods
        def create_proxy_logger(prefix = "", logger_name = self.name, create_class_method = false)
          prefix = prefix.to_s
          if !prefix.blank? && prefix[-1] != '_'
            prefix = "#{prefix}_"
          end
          method_name = "#{prefix}logger"
          class_eval <<-CLASS_EVAL
          def #{create_class_method ? 'self.' : ''}#{method_name}
            return Log4r::Logger['#{logger_name}'] || Log4r::Logger.new('#{logger_name}')
          end
          CLASS_EVAL
        end

        def create_class_proxy_logger(prefix = "", logger_name = self.name)
          create_proxy_logger(prefix, logger_name, true)
        end

        def opt(long_name, *extra_stuff, &b)
          extra_hash = {}
          if extra_stuff[-1].is_a? Hash
            extra_hash = extra_stuff.pop
          end
          extra_stuff.push extra_hash.merge({:target_container => self})
          return ::Af::Application.opt(long_name, *extra_stuff, &b)
        end

        def opt_group(group_name, *extra_stuff, &b)
          extra_hash = {}
          if extra_stuff[-1].is_a? Hash
            extra_hash = extra_stuff.pop
          end
          extra_stuff.push extra_hash.merge({:target_container => self})

          return ::Af::Application.opt_group(group_name, *extra_stuff, &b)
        end
      end

      def af_logger(logger_name = (af_name || "Unknown"))
        return ::Af::Application.singleton.logger(logger_name)
      end

      def af_name
        return ::Af::Application.singleton.try(:af_name)
      end

      def periodic_application_checkpoint
        af_application.try(:periodic_application_checkpoint)
      end

      def protect_from_signals
        af_application.try(:protect_from_signals)
      end

      def af_application
        return ::Af::Application.singleton
      end
    end
  end
end
