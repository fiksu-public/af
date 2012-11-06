require 'spec_helper'

class CLInstance < Af::CommandLiner
  def application_version
    5
  end
end

describe Af::CommandLiner do

  subject { CLInstance.new }
  let(:command_line_usage) { "rails runner ::Process::Naf:Runner.run [OPTIONS]" }
  let(:options) { {
      "--?" => { :argument => 0,
                 :note => "show this help (--?? for all)"
      }
  } }

  it "returns application version when #application_version is called" do
    subject.application_version.should == 5
  end

  it "returns usage instance variable" do
    subject.instance_variable_set(:@usage, command_line_usage)

    subject.usage.should == command_line_usage
  end

  it "returns help options" do
    subject.should_receive(:puts).with(command_line_usage)
    subject.should_receive(:puts).with("basic: basic options\n These are the stanadard options offered to all Af commands.\n    --? | -?                     show this help (--?? for all)\n    --??                         show help for all commands\n    --application-version | -V   application version")

    subject.help(command_line_usage, true)
  end

  it "receives Af::CommandLiner.command_line_options_store" do
    Af::CommandLiner.should_receive(:command_line_options_store)

    subject.command_line_options_store
  end

  it "returns update options" do
    subject.update_opts(:new_option, { :default => ["test"] }).should == { :default=>["test"] }
  end

  it "returns @all_command_line_options_stores" do
    subject.instance_variable_set(:@all_command_line_options_stores, options)

    subject.all_command_line_options_stores.should == options
  end

  it "returns @command_line_options_store" do
    Af::CommandLiner.instance_variable_set(:@command_line_options_store, options)

    Af::CommandLiner.command_line_options_store.should == options
  end

  it "returns @all_command_line_option_groups_stores" do
    subject.instance_variable_set(:@all_command_line_option_groups_stores, options)

    subject.all_command_line_option_groups_stores.should == options
  end

  it "returns @command_line_option_groups_store" do
    Af::CommandLiner.instance_variable_set(:@command_line_option_groups_store, options)

    Af::CommandLiner.command_line_option_groups_store.should == options
  end

end # Af::CommandLiner
