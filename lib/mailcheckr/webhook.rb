# frozen_string_literal: true

require "openssl"

module Mailcheckr
  module Webhook
    DEFAULT_TOLERANCE = 300

    def self.verify_signature(raw_body:, timestamp:, signature:, secret:, tolerance: DEFAULT_TOLERANCE, now: Time.now)
      tolerance = Integer(tolerance)
      raise ArgumentError, "tolerance must not be negative" if tolerance.negative?

      return false unless raw_body.is_a?(String) && secret.is_a?(String) && !secret.empty?
      return false unless timestamp.is_a?(String) && timestamp.match?(/\A\d+\z/)
      return false unless signature.is_a?(String) && signature.match?(/\Av1=[a-fA-F0-9]{64}\z/)

      timestamp_value = Integer(timestamp, 10)
      return false if (now.to_i - timestamp_value).abs > tolerance

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{raw_body}")
      OpenSSL.fixed_length_secure_compare(expected, signature.delete_prefix("v1=").downcase)
    end
  end
end
