module Kernel
  if !self.methods.include?(:silence_warnings)
    def silence_warnings
      old_verbose, $VERBOSE = $VERBOSE, nil
      yield
    ensure
      $VERBOSE = old_verbose
    end
  end
end

class Fiber
  
  #Attribute Reference--Returns the value of a fiber-local variable, using
  #either a symbol or a string name. If the specified variable does not exist,
  #returns nil.
  def [](key)
    local_fiber_variables[key]
  end
  
  #Attribute Assignment--Sets or creates the value of a fiber-local variable,
  #using either a symbol or a string. See also Fiber#[].
  def []=(key,value)
    local_fiber_variables[key] = value
  end
  
  private
  
  def local_fiber_variables
    @local_fiber_variables ||= {}
  end
end