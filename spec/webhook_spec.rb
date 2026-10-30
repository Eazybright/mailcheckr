# frozen_string_literal: true

require "minitest/autorun"
require "openssl"
require "mailcheckr/webhook"

class MailcheckrWebhookSpec < Minitest::Test
  SECRET = "webhook-secret"
  RAW_BODY = '{"id":"event_123","type":"verification.completed"}'
  NOW = Time.at(1_800_000_000)

  def signed_headers(timestamp: NOW.to_i.to_s, raw_body: RAW_BODY)
    signed_payload = "#{timestamp}.#{raw_body}"
    signature = OpenSSL::HMAC.hexdigest("SHA256", SECRET, signed_payload)
    { timestamp: timestamp, signature: "v1=#{signature}" }
  end

  def verify(raw_body: RAW_BODY, timestamp: NOW.to_i.to_s, signature: signed_headers[:signature], secret: SECRET, **options)
    Mailcheckr::Webhook.verify_signature(
      raw_body: raw_body,
      timestamp: timestamp,
      signature: signature,
      secret: secret,
      now: NOW,
      **options
    )
  end

  def test_accepts_a_valid_signature
    headers = signed_headers

    assert Mailcheckr::Webhook.verify_signature(
      raw_body: RAW_BODY,
      timestamp: headers[:timestamp],
      signature: headers[:signature],
      secret: SECRET,
      now: NOW
    )
  end

  def test_rejects_a_modified_body_or_signature
    refute verify(raw_body: "#{RAW_BODY} ")
    refute verify(signature: "v1=#{'0' * 64}")
  end

  def test_rejects_timestamps_outside_tolerance
    stale = (NOW.to_i - Mailcheckr::Webhook::DEFAULT_TOLERANCE - 1).to_s
    future = (NOW.to_i + Mailcheckr::Webhook::DEFAULT_TOLERANCE + 1).to_s

    refute verify(timestamp: stale, signature: signed_headers(timestamp: stale)[:signature])
    refute verify(timestamp: future, signature: signed_headers(timestamp: future)[:signature])
  end

  def test_accepts_timestamp_inside_custom_tolerance
    timestamp = (NOW.to_i - 600).to_s
    signature = signed_headers(timestamp: timestamp)[:signature]

    assert verify(timestamp: timestamp, signature: signature, tolerance: 600)
  end

  def test_rejects_malformed_headers_and_empty_secret
    refute verify(timestamp: "not-a-timestamp")
    refute verify(signature: "sha256=invalid")
    refute verify(secret: "")
  end

  def test_rejects_negative_tolerance
    assert_raises(ArgumentError) { verify(tolerance: -1) }
  end
end
