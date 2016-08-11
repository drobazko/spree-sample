require 'net/https'

require 'adyen/api/response'
require 'adyen/api/xml_querier'

module Adyen
  module API
    # The base class of the API classes that map to Adyen SOAP services.
    class SimpleSOAPClient
      # This method wraps the given XML +data+ in a SOAP envelope and posts it to +action+ on the
      # +endpoint+ defined for the subclass.
      #
      # The result is a response object, with XMLQuerier, ready to be queried.
      #
      # If a {stubbed_response} has been set, then said response is returned and no actual remote
      # calls are made.
      #
      # @param [String]   action         The remote action to call.
      # @param [String]   data           The XML data to post to the remote action.
      # @param [Response] response_class The Response subclass used to wrap the response from Adyen.
      def call_webservice_action(action, data, response_class)
        if response = self.class.stubbed_response
          self.class.stubbed_response = nil
          response
        else
          endpoint = self.class.endpoint

          post = Net::HTTP::Post.new(endpoint.path, 'Accept' => 'text/xml', 'Content-Type' => 'text/xml; charset=utf-8', 'SOAPAction' => action)
          post.basic_auth(Adyen.configuration.api_username, Adyen.configuration.api_password)
          post.body = ENVELOPE % data

          request = Net::HTTP.new(endpoint.host, endpoint.port)
          request.use_ssl = true
          request.ca_file = CACERT
          request.verify_mode = OpenSSL::SSL::VERIFY_PEER
          t = Logger.new(STDOUT)
          t.debug '========================================'
          t.debug 'Adyen.configuration.api_username = ' + Adyen.configuration.api_username
          t.debug 'Adyen.configuration.api_password = ' + Adyen.configuration.api_password
          t.debug 'endpoint.host = ' + endpoint.host
          t.debug 'endpoint.port = ' + endpoint.port.to_s
          t.debug data
          t.debug '========================================'

          request.start do |http|
            http_response = http.request(post)
            response = response_class.new(http_response)
            raise ClientError.new(response, action, endpoint) if http_response.is_a?(Net::HTTPClientError)
            raise ServerError.new(response, action, endpoint) if response.server_error?
            response
          end
        end
      end
    end
  end
end
