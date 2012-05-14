#!/usr/bin/env /Users/keith/sandbox/t/script/rails runner

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

    def work
      opt_error "foo must be less than 100" if @foo >= 100
    end
  end
end
