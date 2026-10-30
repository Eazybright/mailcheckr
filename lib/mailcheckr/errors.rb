# frozen_string_literal: true

require "json"

module Mailcheckr
  class Error < StandardError; end

  class APIError < Error
    attr_reader :status, :response_body, :response, :code, :request_id
    alias status_code status

    def self.for_response(status:, response_body:, request_id: nil)
      error_class = {
        401 => AuthenticationError,
        402 => InsufficientCreditsError,
        403 => EmailVerificationRequiredError,
        409 => IdempotencyConflictError,
        422 => ValidationError
      }[status] || self
      error_class.new(status: status, response_body: response_body, request_id: request_id)
    end

    def initialize(status:, response_body:, request_id: nil)
      @status = status
      @response_body = response_body
      @request_id = request_id
      @response = parse_response(response_body)
      error_details = response.is_a?(Hash) ? response["error"] : nil
      @code = response.is_a?(Hash) ? response["code"] : nil
      @code ||= error_details["code"] if error_details.is_a?(Hash)
      @code ||= error_details if error_details.is_a?(String)
      message_detail = response.is_a?(Hash) ? response["message"] : nil
      message_detail ||= error_details["message"] if error_details.is_a?(Hash)

      message = "MailCheckr API request failed with HTTP #{status}"
      detail = [message_detail, code].find { |value| value.is_a?(String) && !value.empty? }
      message = "#{message}: #{detail}" if detail
      message = "#{message} (request ID: #{request_id})" if request_id && !request_id.empty?
      super(message)
    end

    private

    def parse_response(body)
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end
  end

  class AuthenticationError < APIError; end
  class InsufficientCreditsError < APIError; end
  class EmailVerificationRequiredError < APIError; end
  class IdempotencyConflictError < APIError; end
  class ValidationError < APIError; end

  class ResponseError < Error
    attr_reader :status, :response_body

    def initialize(status:, response_body:)
      @status = status
      @response_body = response_body
      super("MailCheckr API returned invalid JSON with HTTP #{status}")
    end
  end
end
