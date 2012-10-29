require 'spec_helper'

class MyScript < Af::Application
  opt do
    opt :bar
  end

  def work
    puts "baz"
  end
end

class ErrorScript < Af::Application
  opt do
    opt :bar
  end

  def work
    raise Exception
  end
end

describe Af::Application do

  subject { MyScript.new }

  it "returns connections name" do
    subject.set_connection_application_name("Application name")
    ActiveRecord::ConnectionAdapters::ConnectionPool.connection_application_name.should == "Application name"
  end

  it "returns process PID and af name" do
    subject.startup_database_application_name.should =~ /MyScript$/
  end

  it "returns class name" do
    subject.af_name.should == "MyScript"
  end

  it "returns Log4r::Logger instance" do
    subject.logger.should be_kind_of(Log4r::Logger)
  end

  it "performs code from work method" do
    subject.should_receive(:puts).with("baz")
    subject.work
  end

  it "exists with non-zero status when throws exception" do
    lambda { ErrorScript.run }.should raise_error(SystemExit)
  end

  it "exists with non-zero status when throws exception" do
    expect { ErrorScript.run }.to raise_error { |error|
      error.status.should == 1
    }
  end

  it "exists with zero status when throws SystemExit exception" do
    expect { MyScript.run }.to raise_error { |error|
      error.status.should == 0
    }
  end

end # Af::Application
