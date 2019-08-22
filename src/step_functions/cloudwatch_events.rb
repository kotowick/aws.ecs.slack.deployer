# frozen_string_literal: true

load('vendor/bundle/bundler/setup.rb')

require 'pp'
require './src/lib/config'
require './src/lib/store'
require './src/lib/response'
require_relative '../lib/clients'

def lambda_handler(event:, context:)
  Config.load

  Store.update(event['Records'].first)
  Store.update(message: JSON.parse(Store.get[:Sns][:Message]))

  result = {}

  # Lookup more info on the task definition
  task_definition = Clients.ecs(
    Store.get[:message][:region]
  ).describe_task_definition(
    task_definition: Store.get[:message][:detail][:taskDefinitionArn]
  )[:task_definition]

  # Scan table for task family
  params = {
    table_name: Config.get[:APPLICATIONS_TABLE_NAME],
    filter_expression: '#family = :name',
    expression_attribute_names: {
      '#family' => 'ecs_task_definition_family',
    },
    expression_attribute_values: {
      ':name' => task_definition[:family],
    },
  }

  begin
    result = Clients.dynamo(
      Config.get[:AWS_DEFAULT_REGION]
    ).scan(params).items.first

    pp("Updating Dynamo item #{result['id']}")
    update_existing_item(result, task_definition)
    pp("Dynamo item #{result['id']} updated successfully.")
  rescue Aws::DynamoDB::Errors::ServiceError => e
    pp('Unable to query table:')
    pp(e)
  rescue StandardError => e
    pp("An error occured why trying to update Dynamo item #{result['id']}")
    pp(e)
  end

  Response.get(200, result)
end

def update_existing_item(result, task_definition)
  definition = task_definition[:container_definitions].find do |x|
    x[:name] == result['container_service_name']
  end

  raise StandardError, 'Task Definition does not meet the requirements.' if definition.empty?

  config_version = definition[:environment].find do |x|
    Config.get[:CONFIGURATION_VERSION_NAMING_OPTIONS].map(&:downcase)
      .include?(x[:name].downcase)
  end

  application_version = definition[:image].split(':').last

  output_message('config_version',
                 result['current_config_version'],
                 config_version.value)

  output_message('application_version',
                 result['current_application_version'],
                 application_version)

  output_message('ecs_task_definition_id',
                 result['ecs_task_definition_id'],
                 Store.get[:message][:detail][:taskDefinitionArn])

  Clients.dynamo(Config.get[:AWS_DEFAULT_REGION]).update_item(
    table_name: Config.get[:APPLICATIONS_TABLE_NAME],
    return_values: 'ALL_NEW',
    update_expression: 'SET #cav = :cav, #ccv = :ccv, #etdid = :etdid',
    expression_attribute_names: {
      '#cav' => 'current_application_version',
      '#ccv' => 'current_config_version',
      '#etdid' => 'ecs_task_definition_id',
    },
    expression_attribute_values: {
      ':cav' => application_version,
      ':ccv' => config_version.value,
      ':etdid' => Store.get[:message][:detail][:taskDefinitionArn],
    },
    key: {
      'id' => result['id'],
    }
  )
end

def output_message(setting, current_value, new_value)
  pp("Setting #{setting} from #{current_value} to #{new_value}")
end
