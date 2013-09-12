require 'spec_helper'

module Logical
  module ::Af::OptionParser
    describe OptionSelect do
    	# Instantiate Af::Application in order to use the Proxy
    	::Af::Application.new

    	describe "#validate" do
  			let!(:option_select) { ::Af::OptionParser::OptionSelect.new(:check_selects, { targets: [:foo, :bar] }) }
  			before do
  				option_select.target_container.instance_variable_set('@foo', 'foo')
  				option_select.target_variable = 'foo'
  			end

  			it "not raise error when option_select is valid" do
  				option_select.action = :one_of
  				option_select.target_container.should_receive(:foo).and_return('foo')
  				expect { option_select.validate }.not_to raise_error
  			end

  			it "raise error when target_variable is not set" do
  				option_select.targets = []
  				expect { option_select.validate }.to raise_error OptionSelectError,
            'An array of options must be specified'
  			end

  			it "raise error when one_of action is used and number of options instantiated does not equal to 1" do
  				option_select.action = :one_of
  				expect { option_select.validate }.to raise_error OptionSelectError,
            'You must specify only one of these options: foo, bar'
  			end

  			it "raise error when none_or_one_of action is used and number of options instantiated is greater than 1" do
  				option_select.action = :none_or_one_of
  				option_select.target_container.should_receive(:foo).and_return('foo')
  				option_select.target_container.should_receive(:bar).and_return('bar')
  				expect { option_select.validate }.to raise_error OptionSelectError,
            'You must specify no more than one of these options: foo, bar'
  			end

        it "raise error when one_or_more_of action is used and number of options instantiated is less than 1" do
          option_select.action = :one_or_more_of
          expect { option_select.validate }.to raise_error OptionSelectError,
            'You must specify at least one of these options: foo, bar'
        end
    	end

    end
  end
end
