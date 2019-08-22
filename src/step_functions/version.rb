# frozen_string_literal: true

load('vendor/bundle/bundler/setup.rb')

require 'pp'
require './src/lib/config'
require './src/lib/store'
require './src/lib/response'
require_relative '../lib/clients'

def lambda_handler(event:, _context:)
  Config.load
  Store.update(event)

  dynamo_key = Store.get[:body][:command_string].split(' ').join('.')

  status_code = 404
  resp = {}
  extra = { response_url: Store.get[:response_url] }

  begin
    data = Clients.dynamo.get_item(
      key: {
        id: dynamo_key,
      },
      table_name: Config.get[:APPLICATIONS_TABLE_NAME]
    ).item

    resp = slack_success_message(
      dynamo_key,
      data['current_application_version'],
      data['current_config_version'],
      Store.get[:body][:user][:id],
      Store.get[:body][:channel_id]
    )
    status_code = 200
  rescue
    resp = slack_failure_message(
      Store.get[:body][:user][:id],
      Store.get[:body][:channel_id],
      'Could not retrieve information for '\
        "`#{Store.get[:body][:command_string]}` (perhaps spelling?)"
    )
  end

  Response.get(status_code, resp, extra)
end

def slack_success_message(app_name, application_version, config_version, user, channel_id)
  {
    channel: channel_id,
    as_user: false,
    user: user,
    attachments: [
      {
        fallback: "#{app_name}: app version: #{application_version}, config_version: #{config_version}",
        color: '#5087e0',
        title: "#{app_name} is currently running:",
        mrkdwn_in: %w[fields fallback],
        fields: [
          {
            title: 'Application Version',
            value: application_version.to_s,
            short: true,
          },
          {
            title: 'Config Version',
            value: config_version.to_s,
            short: true,
          },
        ],
      },
    ],
  }
end

def slack_failure_message(user, channel_id, text)
  {
    channel: channel_id,
    as_user: false,
    user: user,
    text: text,
    response_type: 'ephemeral',
  }
end
