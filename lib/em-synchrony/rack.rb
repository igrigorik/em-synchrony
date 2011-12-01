require 'em-synchrony'
require 'rack'
require 'em-synchrony/fiber_pool'
require 'evma_httpserver'
module EM::Synchrony
  class Rack
    def self.run(app, options = {})
      options[:port] ||= 3000
      options[:host] ||= '127.0.0.1'
      options[:pool] ||= EM::Synchrony::FiberPool.new(options[:pool_size] || 20)
      server = self.new app, options
      server.run
    end

    class RequestHandler < EM::Connection
      include EM::HttpServer
      attr_accessor :rack_server

      def post_init
       super
       no_environment_strings
      end

      def make_env
        env = {
          'REQUEST_METHOD' => @http_request_method,
          'SCRIPT_NAME' => '',
          'PATH_INFO' => @http_path_info,
          'QUERY_STRING' => @http_query_string || '',
          'SERVER_NAME' => rack_server.host,
          'SERVER_PORT' => rack_server.port.to_s,
          'rack.version' => ::Rack::VERSION,
          'rack.url_scheme' => 'http',
          'rack.multithread' => false,
          'rack.multiprocess' => false, # ???
          'rack.run_once' => false,
          'rack.errors' => $stderr,
        }
        rack_input = StringIO.new(@http_post_content || '')
        rack_input.set_encoding(Encoding::BINARY) if rack_input.respond_to?(:set_encoding)
        env['rack.input'] = rack_input
        env['CONTENT_TYPE'] = @http_content_type if @http_content_type
        @http_headers.split(/\0/).each do |line| 
          header, val = line.split(/:\s*/, 2)
          if header =~ /^HTTP_/
            env[header] = val
          end
        end
        env
      end

      def process_http_request
        rack_server.pool.spawn do
          status, headers, body = rack_server.app.call(make_env)

          send_data "HTTP/1.1 #{status} ...\r\n"
          headers.each { |k, v| send_data "#{k}: #{v}\r\n" }
          send_data "\r\n"

          body.each do |part|
            send_data part
          end
          close_connection_after_writing
        end
      end

    end

    attr_accessor :host, :port, :app, :pool
    def initialize(app, options = {})
      self.app = app
      self.host, self.port = options[:host], options[:port]
      self.pool = options[:pool]
    end

    def run
      EM.start_server(host, port, RequestHandler) do |c|
        c.rack_server = self
      end
    end

  end
end