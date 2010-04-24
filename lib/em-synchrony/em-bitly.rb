begin
  require "em-synchrony/em-http"
  require "bitly"
rescue LoadError => error
  raise "Missing EM-Synchrony dependencies: gem install em-http-request; gem install bitly -v=0.4.0"
end

module Bitly
  module Utils
    def get_result(request)
      http = EventMachine::HttpRequest.new(request).get(:timeout => 100)

      result = if (http.response_header.status == 200)
        Crack::JSON.parse(http.response)
      else
        {'errorMessage' => 'JSON Parse Error(Bit.ly messed up)', 'errorCode' => 69, 'statusCode' => 'ERROR'}
      end

      if 'OK' == result['statusCode']
        result['results']
      else
        raise BitlyError.new(result['errorMessage'],result['errorCode'])
      end
    end
  end
end