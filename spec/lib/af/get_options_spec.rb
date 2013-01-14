require 'spec_helper'

module Af
  describe GetOptions do

    it "returns object with GetOptions class" do
      GetOptions.new({"--another-option" => { :argument => 0 }}).should be_kind_of(GetOptions)
    end

    it "returns the correct @get_options value" do
      GetOptions.new({"--another-option" => { :argument => 0 }}).instance_variable_get("@getopt_options").should == [["--another-option", 0]]
    end

    it "returns passed options" do
      get_options = {"--another-option" => { :argument => 0 },
                     "--foo" => { :argument => 1, :note => 'note' },
                     "--bar" => { :argument => 1, :short => '-b' }}

      GetOptions.new(get_options).instance_variable_get("@command_line_switchs").should == get_options
    end

  end # GetOptions
end # Af
