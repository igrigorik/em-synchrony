module EM::Synchrony
  class Local
    def method_missing(mid, *args)
      mname = mid.id2name
      len = args.length
      if mname.chomp!('=')
        if len != 1
          raise ArgumentError, "wrong number of arguments (#{len} for 1)", caller(1)
        end
        storage[mname] = args[0]
      elsif len == 0
        storage[mname]
      else
        raise NoMethodError, "undefined method `#{mname}' for #{self}", caller(1)
      end
    end

    def storage
      key = "locals_storage_#{Fiber.current.object_id}"
      Fiber.current[key] ||= {}
    end
  end
end