# franco - deploy ecs apps via slack
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/b0fb27975ff04147a8a997d50af608c4)](https://app.codacy.com/app/SpekoTechnologies/aws.ecs.slack.deployer?utm_source=github.com&utm_medium=referral&utm_content=SpekoTechnologies/aws.ecs.slack.deployer&utm_campaign=Badge_Grade_Dashboard)
[![serverless](http://public.serverless.com/badges/v3.svg)](http://www.serverless.com)
[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/amplify-education/serverless-domain-manager/master/LICENSE)

## About Speko Technologies
Speko was born out of a vision. We believed that cloud technology through AWS would be the future of cloud computing. As we worked toward that goal, we grew our team of motivated experts and began to actually work and improve upon our ideas.

*We wanted to share our work with the world, so we started to release tools we have built under MIT licensing.*
Learn more at <https://www.speko.io>

## Getting Started

### Prerequisites
Make sure you have the following installed before starting:
- [ruby](https://www.ruby-lang.org/en/downloads/)
- [npm](https://www.npmjs.com/get-npm?utm_source=house&utm_medium=homepage&utm_campaign=free%20orgs&utm_term=Install%20npm)
- [serverless](https://serverless.com/framework/docs/providers/aws/guide/installation/)

The IAM role that is deploying the lambda will need the following permissions:
```yaml
acm:ListCertificates                *
apigateway:GET                      /domainnames/*
apigateway:GET                      /domainnames/*/basepathmappings
apigateway:DELETE                   /domainnames/*
apigateway:POST                     /domainnames
apigateway:POST                     /domainnames/*/basepathmappings
apigateway:PATCH                    /domainnames/*/basepathmapping
cloudformation:GET                  *
cloudfront:UpdateDistribution       *
route53:ListHostedZones             *
route53:ChangeResourceRecordSets    hostedzone/{HostedZoneId}
route53:GetHostedZone               *
route53:ListResourceRecordSets      *
iam:CreateServiceLinkedRole         arn:aws:iam::${AWS::AccountId}: role/aws-service-role/ops.apigateway.amazonaws.com/AWSServiceRoleForAPIGateway
```

### Installation

#### Plugins
Below is a list of Serverless plugins used by this application.

| Plugin | README |
| ------ | ------ |
| serverless-ruby-package | Allows Ruby development for Serverless |
| serverless-pseudo-parameters | Allows us to grab `#{AWS::AccountId}, #{AWS::Region}` and use CloudFormation resource id as a reference, eg `#{myAwesomeResource}` |
| serverless-step-functions | This is the Serverless Framework plugin for AWS Step Functions. |
| serverless-stage-manager | Super simple plugin for validating stage names before deployment. |
| serverless-certificate-creator | This serverless plugin creates certificates that you need for your custom domains in API Gateway |
| serverless-domain-manage | Create custom domain names that your lambda can deploy to with serverless. Allows for base path mapping when deploying and deletion of domain names. |

```bash
# From npm (recommended)
npm install serverless-ruby-package --save-dev
npm install serverless-pseudo-parameters --save-dev
npm install serverless-step-functions --save-dev
npm install serverless-stage-manager --save-dev
npm install serverless-certificate-creator --save-dev
npm install serverless-domain-manager --save-dev
```

#### Ruby Gems
Now, install the Ruby packages:
`bundle instal`

### Configuration
To make this application easier to setup, all of the dynamic configuration is in a config.yml file. The example file in in `./example`. Copy this file to `./config/`.

| Parameter Name | Default Value | Description |
| --- | --- | --- |
| APP_NAME | `franco` | The name you want to assign to this app. It is referenced in certain places. Also make sure to replace this keyword throughout this configuration file if you change it. |
| ALLOWED_CHANNELS | Examples | Restrictions on where users can run `write` commands, like deployments. |
| APPLICATIONS_TABLE_NAME | `staging-franco-applications` | A Dynamo table where information about ECS applications are stored. |
| AWS_ACCOUNT_NUMBER | Placeholder | Replace this with your AWS Account Number |
| AWS_DEFAULT_REGION | `us-east-1` | The default region of there this application is deployed to. |
| AWS_REGIONS | `us-east-1, eu-west-1, eu-central-1` | The regions where you have your ECS services deployed and want to be deployed via this application. |
| AWS_RETRY_LIMIT | `20` | An exponential backoff limit - this works well for this application to avoid API RATE LIMITING |
| CLOUDWATCH_EVENT_PATTERN_ECS | | The pattern for the CloudWatch Event Rule for ECS Events. |
| CLOUDWATCH_EVENTS_RULE_ECS_NAME | `staging-franco-cloudwatch_ecs_event` | A Cloudwatch Event Rule to send Task Definition changes to an SNS topic. We grab current information about the new task definition and update it's corresponding entry in Dynamo. |
| CONFIGURATION_VERSION_NAMING_OPTIONS | `VERSION, PARAM_VERSION, CONFIG_VERSION` | This app is highly dependent on your ECS Task Definitions containing a parameter defining the configuration version from SSM. You can add/remove options from here. |
| DEFAULT_NAMING | `staging-franco` | Default naming convention - variable is referenced in resources.yml and a few other places. |
| HOSTED_ZONE_ID | `(example - Z0000000000000)` | In order to create a custom sub-domain and ssl certificate, enter the Hosted Zone ID of where you want the sub-domain to be created. |
| MESSAGES |  | Default messages to be used across this application. |
| READ_COMMANDS | `'/version'` | Commands which are read-only and have no write operations within it. By default, all slack users can run any READ_COMMAND. |
| ROOT_DOMAIN | Placeholder | Enter the hosted zone name where you want the sub-domain to be placed. |
| SUB_DOMAIN | `franco` | The sub-domain name that you want. Can be anything. |
| SLACK_TOKEN | Placeholder | Enter your Slack Token here (found in your Slack App - api.slack.com). Example format: xoxp-1111111111-222222222222-333333333333-44444444444444444444444444444444 |
| SLACK_VERIFICATION | Placeholder | Enter your Slack Verification here (found in your Slack App - api.slack.com). Example: AAAABBBBCCCCDDDDEEEEFFFF |
| SNS_TOPIC_NAME | `staging-franco-applications` | A SNS topic for the app which is used for Cloudwatch Events and Deployments. |
| WRITE_COMMANDS | `'/deploy', '/unlock'` | Commands which containts write-operations to AWS services. |
| WRITE_GROUPS | Placeholders | By default, only these Slack User Groups in the WRITE_GROUPS have access to the WRITE_COMMANDS above. |
