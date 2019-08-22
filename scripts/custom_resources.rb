# frozen_string_literal: true

load('vendor/bundle/bundler/setup.rb')

require 'pp'
require './src/lib/clients'
require './src/lib/config'

ENV['CONFIG_FILE'] = "config.#{ENV['STAGE'].downcase}.yml"
Config.load

class Resources
  def initialize
    @subscription_protcol = 'lambda'
    @lambda_function_arn = "arn:aws:lambda:#{Config.get[:AWS_DEFAULT_REGION]}"\
                           ":#{Config.get[:AWS_ACCOUNT_NUMBER]}:function:"\
                           "#{Config.get[:DEFAULT_NAMING]}-cloudwatchEvents"
    @cloudwatch_event_rule = Config.get[:CLOUDWATCH_EVENTS_RULE_ECS_NAME]
    @cloudwatch_event_rule_target_id = "#{@cloudwatch_event_rule}-id"
  end

  def sns_policy(topic_arn)
    {
      'Version' => '2008-10-17',
      'Id' => 'default-policy',
      'Statement' => [
        {
          'Sid' => 'default-allow-statement',
          'Effect' => 'Allow',
          'Principal' => {
            'AWS' => '*',
          },
          'Action' => [
            'SNS:GetTopicAttributes',
            'SNS:SetTopicAttributes',
            'SNS:AddPermission',
            'SNS:RemovePermission',
            'SNS:DeleteTopic',
            'SNS:Subscribe',
            'SNS:ListSubscriptionsByTopic',
            'SNS:Publish',
            'SNS:Receive',
          ],
          'Resource' => topic_arn.to_s,
          'Condition' => {
            'StringEquals' => {
              'AWS:SourceOwner' => Config.get[:AWS_ACCOUNT_NUMBER].to_s,
            },
          },
        },
        {
          'Sid' => 'cloudwatch-events-allow-statement',
          'Effect' => 'Allow',
          'Principal' => {
            'Service' => 'events.amazonaws.com',
          },
          'Action' => ['SNS:Publish'],
          'Resource' => topic_arn.to_s,
        },
      ],
    }.to_json
  end

  def create_topic(region)
    puts "Creating SNS Topic #{Config.get[:SNS_TOPIC_NAME]} for #{region}."
    Clients.sns(region).create_topic(name: Config.get[:SNS_TOPIC_NAME]).topic_arn
  end

  def set_topic_attributes(region, topic_arn)
    puts "Updating policy access for SNS Topic #{Config.get[:SNS_TOPIC_NAME]} in #{region}."
    Clients.sns(region).set_topic_attributes(
      topic_arn: topic_arn,
      attribute_name: 'Policy',
      attribute_value: sns_policy(topic_arn)
    )
  end

  def subscribe_to_sns(region, topic_arn)
    puts "Subscribing #{@lambda_function_arn} to SNS Topic #{Config.get[:SNS_TOPIC_NAME]} in #{region}."
    Clients.sns(region).subscribe(
      topic_arn: topic_arn,
      protocol: @subscription_protcol,
      endpoint: @lambda_function_arn
    )
  end

  def add_permissions_to_lambda_function(region, topic_arn)
    remove_permissions_from_lambda_function(region)

    puts "Adding Permissions to Lambda Function #{@lambda_function_arn} in #{region}."
    Clients.lambda(Config.get[:AWS_DEFAULT_REGION]).add_permission(
      action: 'lambda:InvokeFunction',
      function_name: @lambda_function_arn,
      principal: 'sns.amazonaws.com',
      source_arn: topic_arn,
      statement_id: "sns-#{region}"
    )
  end

  def create_cloudwatch_event_rule(region)
    puts "Creating CloudWatch Event Rule #{@cloudwatch_event_rule} in #{region}."
    Clients.cloudwatch_events(region).put_rule(
      name: @cloudwatch_event_rule,
      event_pattern: Config.get[:CLOUDWATCH_EVENT_PATTERN_ECS].to_json,
      state: 'ENABLED',
      description: "ECS Events for #{Config.get[:DEFAULT_NAMING]}"
    )
  end

  def add_target_to_cloudwatch_event_rule(region, topic_arn)
    puts "Adding SNS Topic as Target to CloudWatch Event Rule in #{region}."
    Clients.cloudwatch_events(region).put_targets(
      rule: @cloudwatch_event_rule,
      targets: [
        {
          id: @cloudwatch_event_rule_target_id,
          arn: topic_arn,
        },
      ]
    )
  end

  def delete_topic(region)
    puts "Removing SNS TOPIC #{Config.get[:SNS_TOPIC_NAME]} in #{region}."
    begin
      Clients.sns(region).delete_topic(
        topic_arn: "arn:aws:sns:#{region}:#{Config.get[:AWS_ACCOUNT_NUMBER]}:#{Config.get[:SNS_TOPIC_NAME]}"
      )
    rescue Aws::SNS::Errors::ResourceNotFoundException => e
      pp(e)
    end
  end

  def remove_permissions_from_lambda_function(region)
    puts "Removing Function Policy for #{@lambda_function_arn} in #{region}."
    begin
      Clients.lambda(Config.get[:AWS_DEFAULT_REGION]).remove_permission(
        function_name: @lambda_function_arn,
        statement_id: "sns-#{region}"
      )
    rescue Aws::Lambda::Errors::ResourceNotFoundException => e
      pp(e)
    end
  end

  def remove_targets(region)
    pp("Removing CloudWatch Event Targets for #{@cloudwatch_event_rule} in"\
       "#{region}.")
    begin
      Clients.cloudwatch_events(region).remove_targets(
        rule: @cloudwatch_event_rule, # required
        ids: [@cloudwatch_event_rule_target_id]
      )
    rescue Aws::CloudWatchEvents::Errors::ResourceNotFoundException => e
      pp(e)
    end
  end

  def delete_rules(region)
    puts "Removing CloudWatch Event #{@cloudwatch_event_rule} for #{region}."

    begin
      Clients.cloudwatch_events(region).delete_rule(name: @cloudwatch_event_rule)
    rescue Aws::CloudWatchEvents::Errors::ResourceNotFoundException => e
      pp(e)
    end
  end

  def create(region)
    topic_arn = create_topic(region)
    set_topic_attributes(region, topic_arn)
    subscribe_to_sns(region, topic_arn)
    add_permissions_to_lambda_function(region, topic_arn)
    create_cloudwatch_event_rule(region)
    add_target_to_cloudwatch_event_rule(region, topic_arn)
  end

  def remove(region)
    delete_topic(region)
    remove_permissions_from_lambda_function(region)
    remove_targets(region)
    delete_rules(region)
  end
end

resource = Resources.new

Config.get[:AWS_REGIONS].each do |region|
  resource.create(region) if ENV['ACTION'] == 'CREATE'
  resource.remove(region) if ENV['ACTION'] == 'REMOVE'
  puts "\n"
end
