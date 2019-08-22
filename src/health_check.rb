# frozen_string_literal: true

load('vendor/bundle/bundler/setup.rb')

require './src/lib/response'

def lambda_handler(*)
  Response.get(200, body: Config.get[:MESSAGES][:health_check_status])
end
