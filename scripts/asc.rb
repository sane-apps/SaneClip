#!/usr/bin/env ruby
# frozen_string_literal: true

# Thin App Store Connect diagnostic client. Authentication, bounded transport,
# JSON parsing, and retry policy stay owned by shared SaneProcess tooling.
# Usage: ruby scripts/asc.rb GET|POST|PATCH|DELETE /v1/path ['{"data":{...}}']

require 'json'

def run_asc_request!(argv)
  method, raw_path, raw_body = argv
  allowed_methods = %w[GET POST PATCH DELETE]
  unless allowed_methods.include?(method) && raw_path&.match?(%r{\A/v[12]/[^\s\\]*\z})
    warn 'usage: asc.rb GET|POST|PATCH|DELETE /v1/path [json-body]'
    exit 2
  end

  if %w[GET DELETE].include?(method) && raw_body
    warn "#{method} does not accept a request body"
    exit 2
  end

  body = JSON.parse(raw_body) if raw_body
  shared_client = File.expand_path('../../../infra/SaneProcess/scripts/appstore_submit.rb', __dir__)
  abort "shared App Store client is missing: #{shared_client}" unless File.file?(shared_client)
  require shared_client

  base = raw_path.start_with?('/v2/') ? ASC_V2_BASE : ASC_BASE
  path = raw_path.sub(%r{\A/v[12]}, '')
  status, response = case method
                     when 'GET'
                       asc_get_with_status(path, base: base)
                     when 'POST'
                       asc_post_with_status(path, body: body, base: base)
                     when 'PATCH'
                       asc_patch_with_status(path, body: body, base: base)
                     when 'DELETE'
                       asc_delete_with_status(path, base: base)
                     end

  puts "HTTP #{status}"
  puts JSON.generate(response)
  exit(status.between?(200, 299) ? 0 : 1)
rescue JSON::ParserError => e
  warn "invalid JSON body: #{e.message}"
  exit 2
end

run_asc_request!(ARGV) if $PROGRAM_NAME == __FILE__
