# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"
require "mailcheckr"

class MailcheckrClientTest < Minitest::Test
  Response = Struct.new(:code, :body, :headers) do
    def [](name)
      headers[name]
    end
  end

  class FakeHTTP
    attr_reader :last_request

    def initialize(response)
      @response = response
    end

    def request(request)
      @last_request = request
      @response
    end
  end

  def with_response(code: "200", body: '{"data":{"id":"verification-123","state":"completed"}}', request_id: nil)
    headers = request_id ? { "X-Request-Id" => request_id } : {}
    http = FakeHTTP.new(Response.new(code, body, headers))
    start = lambda do |_host, _port, **_options, &block|
      block.call(http)
    end

    Net::HTTP.stub(:start, start) { yield http }
  end

  def test_create_verification_sends_bearer_auth_idempotency_key_and_email
    with_response do |http|
      result = Mailcheckr::Client.new(api_key: "secret").create_verification(
        email: "person@example.com",
        idempotency_key: "verify-person-123"
      )

      assert_equal "verification-123", result["id"]
      assert_equal 200, result.http_status
      assert_equal "Bearer secret", http.last_request["Authorization"]
      assert_equal "verify-person-123", http.last_request["Idempotency-Key"]
      assert_equal "application/json", http.last_request["Content-Type"]
      assert_equal({ "email" => "person@example.com" }, JSON.parse(http.last_request.body))
      assert_equal "/api/v1/verifications", http.last_request.path
    end
  end

  def test_get_verification_quotes_id_as_a_path_segment
    with_response do |http|
      Mailcheckr::Client.new(api_key: "secret").get_verification(id: "verify/123")

      assert_equal "/api/v1/verifications/verify%2F123", http.last_request.path
      assert_nil http.last_request["Idempotency-Key"]
      assert_equal "Bearer secret", http.last_request["Authorization"]
    end
  end

  def test_accepts_a_202_response_for_async_verification
    with_response(code: "202", body: '{"data":{"id":"verification-123","state":"processing"}}') do
      result = Mailcheckr::Client.new(api_key: "secret").create_verification(
        email: "person@example.com",
        idempotency_key: "verify-person-123"
      )

      assert_equal "processing", result["state"]
      assert_equal 202, result.http_status
    end
  end

  def test_raises_api_error_for_non_success_responses
    with_response(
      code: "409",
      body: '{"error":"idempotency_conflict"}',
      request_id: "req_123"
    ) do
      error = assert_raises(Mailcheckr::APIError) do
        Mailcheckr::Client.new(api_key: "secret").create_verification(
          email: "person@example.com",
          idempotency_key: "verify-person-123"
        )
      end

      assert_equal 409, error.status
      assert_equal 409, error.status_code
      assert_equal "idempotency_conflict", error.code
      assert_equal "req_123", error.request_id
      assert_equal '{"error":"idempotency_conflict"}', error.response_body
    end
  end

  def test_maps_documented_error_statuses_to_specific_error_classes
    cases = {
      "401" => Mailcheckr::AuthenticationError,
      "402" => Mailcheckr::InsufficientCreditsError,
      "403" => Mailcheckr::EmailVerificationRequiredError,
      "409" => Mailcheckr::IdempotencyConflictError,
      "422" => Mailcheckr::ValidationError
    }

    cases.each do |status, error_class|
      with_response(code: status, body: '{"code":"api_error","message":"Request rejected"}') do
        error = assert_raises(error_class) do
          Mailcheckr::Client.new(api_key: "secret").get_verification(id: "verification-123")
        end

        assert_equal status.to_i, error.status
        assert_equal "api_error", error.code
        assert_equal "Request rejected", error.response["message"]
        assert_includes error.message, "Request rejected"
      end
    end
  end

  def test_extracts_error_details_from_nested_error_object
    with_response(code: "402", body: '{"error":{"code":"insufficient_credits","message":"No credits left"}}') do
      error = assert_raises(Mailcheckr::InsufficientCreditsError) do
        Mailcheckr::Client.new(api_key: "secret").get_verification(id: "verification-123")
      end

      assert_equal "insufficient_credits", error.code
      assert_includes error.message, "No credits left"
    end
  end

  def test_raises_response_error_for_invalid_json
    with_response(body: "not json") do
      error = assert_raises(Mailcheckr::ResponseError) do
        Mailcheckr::Client.new(api_key: "secret").get_verification(id: "verification-123")
      end

      assert_equal 200, error.status
      assert_equal "not json", error.response_body
    end
  end

  def test_raises_response_error_when_data_envelope_is_missing
    with_response(body: '{"id":"verification-123","state":"completed"}') do
      error = assert_raises(Mailcheckr::ResponseError) do
        Mailcheckr::Client.new(api_key: "secret").get_verification(id: "verification-123")
      end

      assert_equal 200, error.status
    end
  end

  def test_requires_an_api_key_and_idempotency_key
    assert_raises(ArgumentError) { Mailcheckr::Client.new(api_key: "") }
    client = Mailcheckr::Client.new(api_key: "secret")
    assert_raises(ArgumentError) do
      client.create_verification(email: "person@example.com", idempotency_key: "")
    end
  end
end
