# frozen_string_literal: true

load('vendor/bundle/bundler/setup.rb')

require 'pp'
require 'json'
require './src/lib/config'
require './src/lib/store'
require './src/lib/clients'

ECS_RESOURCE_TYPE = 'AWS::ECS::Service'.freeze!

def init
  ENV['CONFIG_FILE'] = "config.#{ENV['STAGE'].downcase}.yml"
  Config.load

  Config.get[:AWS_REGIONS].each do |region|
    perform(region)
  end
end

def perform(region)
  Store.update(AWS_REGION: region)

  puts "Scanning #{Store.get[:AWS_REGION]} for ECS services"
  # Step 1: get clusters and the services for each
  cluster_services = list_clusters_with_services

  # Step 2 - get cloudformation stack id for the service
  stacks = describe_stacks([], nil)

  stacks.each do |stack|
    # Generate Dynamo Key
    service_name = stack.parameters.find do |k|
      k[:parameter_key].casecmp('servicename')
    end

    prefix = stack.parameters.find { |k| k[:parameter_key].casecmp('prefix') }
    next if service_name.blank? || prefix.blank?

    # Get stack resources
    resources = list_resources(stack[:stack_id], stack[:stack_name], [], nil)
    stack_needle = resources.find { |r| r[:resource_type] == ECS_RESOURCE_TYPE }
    next if resources.empty? || stack_needle.empty?

    # Get corresponding cluster
    cluster_service = cluster_services.find do |x|
      x[:services].map(&:service_arn).include?(stack_needle[:service_id])
    end

    next if cluster_service.empty?

    # Get current service version
    service = cluster_service[:services].find do |x|
      x[:service_arn] == stack_needle[:service_id]
    end

    cd = container_definition(
      service[:task_definition],
      service_name[:parameter_value].split('_').join('-')
    )

    # Insert into Dynamo
    key = prefix[:parameter_value].split('-')
    dynamo_key = "#{key[2]}.#{key[0]}.#{key[1]}.#{service_name[:parameter_value]
                 .downcase.tr('-', '_')}"

    begin
      Clients.dynamo(Config.get[:AWS_DEFAULT_REGION]).put_item(
        table_name: Config.get[:APPLICATIONS_TABLE_NAME],
        item: {
          id: dynamo_key,
          current_application_version: cd[:application_version],
          current_config_version: cd[:config_version],
          ecs_cluster_id: cluster_service[:cluster],
          cf_stack_id: stack[:stack_id],
          ecs_stack_name: stack[:stack_name],
          ecs_service_id: stack_needle[:service_id],
          ecs_task_definition_id: service[:task_definition],
          ecs_task_definition_family: cd[:task_definition_family],
          container_service_name: service_name[:parameter_value].split('_')
                                                                .join('-'),
        }
      )
    rescue
      puts "Could not enter #{dynamo_key} into table."
    end
  end
end

def list_clusters_with_services
  list_clusters([]).map do |cluster|
    services = list_services([], cluster)
    { cluster: cluster, services: describe_services(services, cluster) }
  end
end

def container_definition(task_definition, service_name)
  response = describe_task_definition(task_definition)
  definition = response[:container_definitions]
    .find { |x| x[:name] == service_name }

  config_version = definition[:environment].find do |x|
    Config.get[:CONFIGURATION_VERSION_NAMING_OPTIONS].map(&:downcase)
      .include?(x[:name].downcase)
  end

  application_version = definition[:image].split(':').last

  {
    task_definition_arn: response[:task_definition_arn],
    task_definition_family: response[:family],
    config_version: config_version.try(:value),
    application_version: application_version,
  }
end

def describe_task_definition(task_definition)
  Clients.ecs(Store.get[:AWS_REGION]).describe_task_definition(
    task_definition: task_definition
  )[:task_definition]
end

def list_clusters(clusters, next_token = nil)
  response = Clients.ecs(Store.get[:AWS_REGION]).list_clusters(
    next_token: next_token
  )

  clusters.append(response.cluster_arns)

  return clusters.flatten.compact if response.next_token.nil?

  list_clusters(clusters, response.next_token)
end

def describe_services(service_arns, cluster)
  services = []

  service_arns.each_slice(10) do |slice|
    response = Clients.ecs(Store.get[:AWS_REGION]).describe_services(
      cluster: cluster, services: slice
    )
    services.append(response.services)
  end

  services.flatten.compact
end

def list_services(services, cluster, next_token = nil)
  response = Clients.ecs(Store.get[:AWS_REGION]).list_services(
    cluster: cluster, next_token: next_token
  )

  services.append(response.service_arns)

  return services.flatten.compact if response.next_token.nil?

  list_services(services, cluster, response.next_token)
end

def describe_stacks(stacks, next_token = nil)
  response = Clients.cloudformation(Store.get[:AWS_REGION]).describe_stacks(
    next_token: next_token
  )

  local_stacks = response[:stacks].select do |s|
    !s[:parameters].empty? && !s[:parameters].map do |k|
      %w[servicename prefix].include?(k[:parameter_key].downcase)
    end.empty?
  end.flatten

  stacks.append(local_stacks)

  return stacks.flatten.compact if response.next_token.nil?

  describe_stacks(stacks, response.next_token) unless response.next_token.nil?
end

def list_resources(stack_id, stack_name, resources, next_token = nil)
  response = Clients.cloudformation(Store.get[:AWS_REGION]).list_stack_resources(
    stack_name: stack_name,
    next_token: next_token
  )

  if response[:stack_resource_summaries].map(&:resource_type).include?(ECS_RESOURCE_TYPE)
    response[:stack_resource_summaries].each do |r|
      resources.append(
        stack_id: stack_id,
        stack_name: stack_name,
        resource_type: r[:resource_type],
        service_id: r[:physical_resource_id]
      )
    end
  end

  return resources.flatten.compact if response.next_token.nil?

  list_resources(stack_name, resources, response.next_token) unless response.next_token.nil?
end

init
