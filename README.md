# MailCheckr Ruby SDK

[![Tests](https://github.com/Eazybright/mailcheckr/actions/workflows/test.yml/badge.svg)](https://github.com/Eazybright/mailcheckr/actions/workflows/test.yml)
[![Gem Version](https://img.shields.io/gem/v/mailcheckr.svg)](https://rubygems.org/gems/mailcheckr)
[![Gem](https://img.shields.io/gem/dt/mailcheckr.svg)](https://rubygems.org/gems/mailcheckr/)

A minimal Ruby client for the [MailCheckr API](https://mailcheckr.app/docs). It uses Ruby's
standard HTTP and JSON libraries.

## Requirements

Ruby 3.2 or newer.

## Installation

You can install the client library via RubyGems:

```ruby
gem install mailcheckr
```

or add it to your Gemfile:

```ruby
gem "mailcheckr"
```

Then run `bundle install`.

## Usage

Create a client with an API key from your MailCheckr dashboard:

```ruby
require "mailcheckr"

client = Mailcheckr::Client.new(api_key: ENV.fetch("MAILCHECKR_API_KEY"))
```

Create a verification. MailCheckr requires an `Idempotency-Key`; use a stable
unique value when retrying the same operation. The result remains hash-like,
and `http_status` distinguishes an immediately completed response from one to
poll:

```ruby
result = client.create_verification(
  email: "person@example.com",
  idempotency_key: "signup-123"
)

case result.http_status
when 200
  puts result["status"]
when 202
  result = client.get_verification(id: result.fetch("id"))
end
```

Creation returns the parsed `data` object as a hash-like
`Mailcheckr::VerificationResponse`. Both `200 OK` and `202 Accepted` responses
include `http_status`; poll the returned ID after `202` until the state is
`completed` or `failed`.

The client also accepts a custom base URL and HTTP timeouts:

```ruby
client = Mailcheckr::Client.new(
  api_key: ENV.fetch("MAILCHECKR_API_KEY"),
  base_url: "https://mailcheckr.app/api/v1",
  open_timeout: 5,
  read_timeout: 30
)
```

## Webhook signatures

Verify webhook deliveries using the exact raw request body, the
`X-MailCheckr-Timestamp` header, the `X-MailCheckr-Signature` header, and the
signing secret shown when configuring the webhook:

```ruby
valid = Mailcheckr::Webhook.verify_signature(
  raw_body: request.raw_post,
  timestamp: request.headers["X-MailCheckr-Timestamp"],
  signature: request.headers["X-MailCheckr-Signature"],
  secret: ENV.fetch("MAILCHECKR_WEBHOOK_SECRET")
)

halt 401 unless valid
```

MailCheckr signs `timestamp + "." + raw_body` with HMAC-SHA256 and sends the
hex digest as `v1=<digest>`. Verification uses a constant-time comparison and
rejects timestamps more than five minutes away from the current time. Set the
`tolerance:` option in seconds to change that window.

## Errors

Non-2xx responses raise `Mailcheckr::APIError` (or a more specific subclass).
Errors expose `status`/`status_code`, parsed `response`, raw `response_body`,
API `code`, and `request_id` when the server supplies an `X-Request-Id` header.
Their message includes the HTTP status and API message/code when present.

```ruby
begin
  client.create_verification(email: email, idempotency_key: key)
rescue Mailcheckr::InsufficientCreditsError => error
  logger.error("MailCheckr #{error.status} #{error.code}: #{error.message}")
rescue Mailcheckr::APIError => error
  logger.error("MailCheckr request failed: #{error.status} #{error.response_body}")
end
```

Documented error statuses map to `AuthenticationError` (401),
`InsufficientCreditsError` (402), `EmailVerificationRequiredError` (403),
`IdempotencyConflictError` (409), and `ValidationError` (422). All inherit
from `APIError`. Invalid JSON or an unexpected response envelope on a
successful status raises `Mailcheckr::ResponseError`. Network and timeout
errors from `Net::HTTP` are propagated to the caller.

## Development

Run the test suite with:

```sh
bin/setup
bundle exec rake test
```

Start an interactive Ruby console with:

```sh
bin/console
```
