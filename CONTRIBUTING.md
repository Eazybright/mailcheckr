# Contributing

## Setup

Use Ruby 3.2 or newer. From the project root, install the development
dependencies:

```sh
bin/setup
```

## Tests

Run the test suite before submitting changes:

```sh
bundle exec rake test
```

Add or update specs in `spec/` for behavior changes.

## Formatting and linting

Run RuboCop to check style:

```sh
bundle exec rubocop
```

Apply safe and unsafe autocorrections, then review the diff before committing:

```sh
bundle exec rubocop -A
```

## Changes

Keep changes focused, follow the existing Ruby style, and update the README
when public behavior or usage changes. Do not include API keys, webhook
secrets, or other credentials in commits.