# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require_relative "errors"

module Mailcheckr
  class VerificationResponse < Hash
    attr_reader :http_status

    def initialize(http_status:, data:)
      super()
      update(data)
      @http_status = http_status
    end
  end

  class Client
    DEFAULT_BASE_URL = "https://mailcheckr.app/api/v1"

    def initialize(api_key:, base_url: DEFAULT_BASE_URL, open_timeout: 5, read_timeout: 30)
      raise ArgumentError, "api_key must not be empty" if api_key.nil? || api_key.empty?

      @api_key = api_key
      @base_url = normalize_base_url(base_url)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def create_verification(email:, idempotency_key:)
      raise ArgumentError, "idempotency_key must not be empty" if idempotency_key.nil? || idempotency_key.empty?

      request(
        Net::HTTP::Post,
        "verifications",
        body: { email: email },
        idempotency_key: idempotency_key
      )
    end

    def get_verification(id:)
      raise ArgumentError, "id must not be empty" if id.nil? || id.to_s.empty?

      encoded_id = URI.encode_www_form_component(id.to_s).gsub("+", "%20")
      request(Net::HTTP::Get, "verifications/#{encoded_id}")
    end

    private

    def normalize_base_url(base_url)
      uri = URI.parse(base_url)
      unless %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo && !uri.query && !uri.fragment
        raise ArgumentError, "base_url must be an HTTP(S) URL without credentials, query, or fragment"
      end

      uri.to_s.sub(%r{/+\z}, "")
    rescue URI::InvalidURIError
      raise ArgumentError, "base_url must be a valid HTTP(S) URL"
    end

    def request(http_method, path, body: nil, idempotency_key: nil)
      uri = URI.join("#{@base_url}/", path)
      request = http_method.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Accept"] = "application/json"

      unless body.nil?
        request["Content-Type"] = "application/json"
        request["Idempotency-Key"] = idempotency_key if idempotency_key
        request.body = JSON.generate(body)
      end

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: @open_timeout,
        read_timeout: @read_timeout
      ) { |http| http.request(request) }

      status = response.code.to_i
      response_body = response.body.to_s
      request_id = response["X-Request-Id"]
      unless (200..299).cover?(status)
        raise APIError.for_response(status: status, response_body: response_body, request_id: request_id)
      end

      parsed_body = JSON.parse(response_body)
      data = parsed_body.is_a?(Hash) ? parsed_body["data"] : nil
      raise ResponseError.new(status: status, response_body: response_body) unless data.is_a?(Hash)

      VerificationResponse.new(http_status: status, data: data)
    rescue JSON::ParserError
      raise ResponseError.new(status: status, response_body: response_body)
    end
  end
end
