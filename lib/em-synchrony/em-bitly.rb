require 'bitly'
require 'eventmachine'
require 'fiber'
require 'em-synchrony/em-http'

module Bitly
  module Utils   
    #Be Aware suported only version Bitly-0.4.0.
	#In next version (in branch) of Bitly library interface changed.
    def get_result(request)      
      http = EventMachine::HttpRequest.new(request).get(:timeout => 100)
      
      result = if(http.response_header.status == 200)
        Crack::JSON.parse(http.response)
      else
        {'errorMessage' => 'JSON Parse Error(Bit.ly messed up)', 'errorCode' => 69, 'statusCode' => 'ERROR'}
      end			
      
      if 'OK'==result['statusCode'] 
        result['results']
      else
        raise BitlyError.new(result['errorMessage'],result['errorCode'])
      end
    end
    
  end
end