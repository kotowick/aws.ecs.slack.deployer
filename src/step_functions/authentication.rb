# frozen_string_literal: true

load('vendor/bundle/bundler/setup.rb')

require 'cgi'
require './src/lib/config'
require './src/lib/store'
require './src/lib/response'
require_relative '../lib/clients'

def lambda_handler(event:, _context:)
  Config.load

  # Configure slack authentication via SLACK_TOKEN
  Slack.configure do |config|
    config.token = Config.get[:SLACK_TOKEN]
  end

  # Seed the STORE with data
  init_store(CGI.parse(event))

  # If the inbound SLACK TOKEN does not match our records,
  # then this command did not come from our Slack organization
  return Response.get(404, Store.get[:fail_message]) if Store.get[:token] != Config.get[:SLACK_VERIFICATION]

  # Read commands can happen in any channel, by any user
  # Therefore, just validate the command is a READ COMMAND and exit
  return Response.get(200, Store.get) if Config.get[:READ_COMMANDS].include?(Store.get[:slash_command])

  # Write commands can happen by users in specific groups
  # Validate:
  # - write command is valid
  # - write command comes from an allowed channel
  # - requesting user is part of the required write group
  # Get a list of usergroups from Slack so we can use it for verification
  usergroups = Clients.slack.usergroups_list(include_users: 'true')['usergroups']
  usergroups_list = usergroups.map { |x| x if Config.get[:WRITE_GROUPS].include?(x[:id]) }.compact

  if Config.get[:WRITE_COMMANDS].include?(Store.get[:slash_command]) &&
     usergroups_list.map(&:users).flatten.compact.include?(user[:id])
    update_store(message: '')
    return Response.get(200, Store.get)
  end

  # Default Response
  Response.get(404, Store.get['fail_message'])
end

# Initialize the local store by setting data from
def init_store(data)
  Store.update(
    token: data['token'].first,
    slash_command: data['command'].first,
    command_string: data['text'].first,
    trigger_id: data['trigger_id'].first,
    channel_id: data['channel_id'].first,
    team_id: data['team_id'].first,
    response_url: data['response_url'].first,
    user: {
      name: data['user_name'].first,
      id: data['user_id'].first,
    },
    fail_message: Config.get[:MESSAGES][:user_not_authenticated],
    success_message: "Processing request for `#{data['command'].first}"\
                     "#{data['text'].first}`"
  )
end
