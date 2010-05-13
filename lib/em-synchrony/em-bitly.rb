require 'cgi'

begin
  require "em-synchrony/em-http"
  require "bitly"
rescue LoadError => error
  raise "Missing EM-Synchrony dependencies: gem install em-http-request; gem install bitly -v=0.5.0"
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
  
  module V3
    class Client
      class << self
        def get(method, query)
          query_values=[]
          query[:query].each do |key, value|
            query_values << "#{key}=#{CGI::escape(value.to_s)}"
          end
          query_values=query_values.join('&')
          request=(method[0]=='/' ? "#{base_uri}#{method}" : method)
          request=(request.include?('?') ? "#{request}&#{query_values}" :  "#{request}?#{query_values}")
          
          http = EventMachine::HttpRequest.new(request).get(:timeout => 100)
          response = if (http.response_header.status == 200)
            Crack::JSON.parse(http.response)
          else
            {'errorMessage' => 'JSON Parse Error(Bit.ly messed up)', 'errorCode' => 69, 'statusCode' => 'ERROR'}
          end      
          
          if response['status_code'] == 200
            return response
          else
            raise BitlyError.new(response['status_txt'], response['status_code'])
          end
          
        end
      end
    end
  end	
end