# frozen_string_literal: true

require 'aws-sdk-cloudformation'
require 'aws-sdk-ecs'
require 'aws-sdk-dynamodb'
require 'aws-sdk-sns'
require 'aws-sdk-ecs'
require 'aws-sdk-cloudwatchevents'
require 'aws-sdk-lambda'
require 'slack-ruby-client'

require './src/lib/config'

module Clients
  def self.slack
    @slack ||= Slack::Web::Client.new
  end

  def self.dynamo(region = ENV['DEPLOYED_REGION'],
    retry_limit = Config.get[:AWS_RETRY_LIMIT])
    Aws::DynamoDB::Client.new(region: region, retry_limit: retry_limit)
  end

  def self.cloudformation(region = ENV['DEPLOYED_REGION'],
    retry_limit = Config.get[:AWS_RETRY_LIMIT])
    Aws::CloudFormation::Client.new(region: region, retry_limit: retry_limit)
  end

  def self.cloudwatch_events(region = ENV['DEPLOYED_REGION'],
    retry_limit = Config.get[:AWS_RETRY_LIMIT])
    Aws::CloudWatchEvents::Client.new(region: region, retry_limit: retry_limit)
  end

  def self.lambda(region = ENV['DEPLOYED_REGION'],
    retry_limit = Config.get[:AWS_RETRY_LIMIT])
    Aws::Lambda::Client.new(region: region, retry_limit: retry_limit)
  end

  def self.sns(region = ENV['DEPLOYED_REGION'],
    retry_limit = Config.get[:AWS_RETRY_LIMIT])
    Aws::SNS::Client.new(region: region, retry_limit: retry_limit)
  end

  def self.ecs(region = ENV['DEPLOYED_REGION'],
    retry_limit = Config.get[:AWS_RETRY_LIMIT])
    Aws::ECS::Client.new(region: region, retry_limit: retry_limit)
  end
end
