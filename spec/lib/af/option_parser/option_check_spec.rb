require 'spec_helper'

module Logical
  module ::Af::OptionParser
    describe OptionCheck do
    	# Instantiate Af::Application in order to use the Proxy
    	::Af::Application.new

    	describe "#validate" do
        let!(:option_check) { ::Af::OptionParser::OptionCheck.new(:foo, { targets: [:bar] }) }
        before do
          option_check.target_container.instance_variable_set('@foo', 'foo')
          option_check.target_variable = 'foo'
        end

        it "not raise error when option_check is valid" do
          option_check.action = :requires
          option_check.target_container.should_receive(:foo).and_return('foo')
          option_check.target_container.should_receive(:bar).and_return('bar')
          expect { option_check.validate }.not_to raise_error
        end

        it "raise error when target_variable is not set" do
          expect { option_check.validate }.to raise_error OptionCheckError, 'foo must be specified'
        end

        it "raise error when target_variable is not set" do
          option_check.targets = []
          option_check.target_container.should_receive(:foo).and_return('foo')
          option_check.should_receive(:action).and_return('required')
          expect { option_check.validate }.to raise_error OptionCheckError, 'An array of required options must be specified'
        end

        it "raise error when required options are not instantiated" do
          option_check.action = :requires
          option_check.target_container.should_receive(:foo).and_return('foo')
          option_check.target_container.should_receive(:bar).and_return(nil)
          expect { option_check.validate }.to raise_error OptionCheckError, 'You must specify these options: bar'
        end

        it "raise error when excluded options are instantiated" do
          option_check.action = :excludes
          option_check.target_container.should_receive(:foo).and_return('foo')
          option_check.target_container.should_receive(:bar).and_return('bar')
          expect { option_check.validate }.to raise_error OptionCheckError, 'You cannot specify these options: bar'
        end
      end
    end
  end
end
