module Af::Deprecated
  def self.included(base)
    base.extend(ClassMethods)
  end

  def update_opts(*x)
    puts "don't use update_opts -- use #opt (#{caller.first})"
    self.class.opt *x
  end

  module ClassMethods
  end
end
