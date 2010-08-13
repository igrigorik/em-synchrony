module EventMachine::Protocols::Memcache
  %w[delete get set].each do |type|
    module_eval %[
      alias :a#{type} :#{type}
      def #{type}(*params, &blk)
        f = Fiber.current
        self.a#{type}(*params) { |*cb_params| f.resume(*cb_params) }

        Fiber.yield
      end
    ]
  end

  alias :aget_hash :get_hash
  def get_hash(*keys)
    index = 0
    get(*keys).inject({}) { |h,v| h[keys[index]] = v; index += 1; h }
  end
end
