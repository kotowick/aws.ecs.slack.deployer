# frozen_string_literal: true

load('vendor/bundle/bundler/setup.rb')

require 'pp'
require 'net/http'
require 'uri'
require 'json'
require './src/lib/config'
require './src/lib/store'
require './src/lib/response'
require_relative '../lib/clients'

def lambda_handler(event:, _context:)
  Config.load
  Store.update(event)

  Slack.configure do |config|
    config.token = Config.get[:SLACK_TOKEN]
  end

  resp = if Store.get[:extra][:response_url]
    http_post_response
  else
    slack_response
  end

  Response.get(200, resp)
end

def slack_response
  Clients.slack.chat_postEphemeral(Store.get[:body])
end

def http_post_response
  uri = URI.parse(Store.get[:extra][:response_url])
  header = { 'Content-Type' => 'application/json' }

  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.request_uri, header)
  request.body = Store.get[:body].to_json
  http.request(request)
end
