# encoding: UTF-8
require 'em-synchrony'

# Monkey-patch
module Kernel
  alias_method :orig_sleep, :sleep

  class << self
    attr_accessor :em_synchrony_sleep_hook
  end

  # Monkey-patch
  def sleep(sleep_time)
    if Kernel.em_synchrony_sleep_hook &&
       EM.reactor_thread? &&
       !Thread.current[:em_synchrony_sleep_hook_called]
      begin
        Thread.current[:em_synchrony_sleep_hook_called] = true
        Kernel.em_synchrony_sleep_hook.call(sleep_time)
      ensure
        Thread.current[:em_synchrony_sleep_hook_called] = false
      end
    else
      orig_sleep(sleep_time)
    end
  end
end
