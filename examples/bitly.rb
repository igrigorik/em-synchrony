require 'lib/em-synchrony'

require "em-synchrony/em-bitly"
EM.synchrony do
  bitly = Bitly.new('[INSERT_LOGIN]', '[INSERT_API_KEY]')
  url = 'http://github.com/igrigorik/em-synchrony'
  short = bitly.shorten(url)

  p "Short #{url} => #{short.jmp_url}"
  EM.stop
end


Bitly.use_api_version_3
EM.synchrony do
  bitly = Bitly.new('[INSERT_LOGIN]', '[INSERT_API_KEY]')

  url = 'http://github.com/igrigorik/em-synchrony'
  domain='nyti.ms'

  pro = bitly.bitly_pro_domain(domain)
  p "Domain #{domain} pro=#{pro}"

  EM.stop
end
