#!/usr/bin/env /Users/keith/sandbox/t/script/rails application

puts "foo"

module ::Af::Examples
  class ScriptWithOptions < ::Af::DaemonProcess
    opt do
      opt :baz
      opt :beltch
    end

    opt :foo, :argument => :required, :type => :int, :env => "FOO", :note => "nothing really", :default => 0, :short => "f"
    opt :bar do |option,argument|
    end

    opt :another_option, "some note"

    def self.run
      puts "baz"
    end

    def work
      puts "foobarbaz"
      opt_error "foo must be less than 100" if @foo >= 100
    end
  end
end

puts "bar"
