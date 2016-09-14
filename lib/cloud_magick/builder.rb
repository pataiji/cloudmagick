require 'zip'
require 'securerandom'
require 'aws-sdk-core'

module CloudMagick
  class Builder
    DEFAULT_REGION  = 'ap-northeast-1'.freeze
    DEFAULT_STAGE   = 'test'.freeze

    def initialize
      create_s3_bucket
      build_lambda
      build_api_gateway
      update_s3_bucket_redirection
      puts endpoint
    end

    def build_lambda
      lambda_client.get_function(function_name: app_name)
    rescue Aws::Lambda::Errors::ResourceNotFoundException
      role = build_lambda_role
      sleep 15 # FIXME
      lambda_client.create_function(
        function_name: app_name,
        runtime: 'nodejs4.3',
        role: role.arn,
        handler: 'index.handler',
        code: { zip_file: File.read(build_zip) },
        description: 'image resizing function',
        timeout: 30,
        memory_size: 1024,
        publish: true,
      )
    end

    def build_zip
      folder = File.join(__dir__, '..', '..', 'templates')
      input_filenames = ['index.js']

      tmp_dir = File.join(__dir__, '..', '..', 'tmp')
      Dir.mkdir(tmp_dir) unless Dir.exist?(tmp_dir)
      filepath = File.join(tmp_dir, 'lambda.zip')
      File.delete(filepath) if File.exist?(filepath)
      Zip::File.open(filepath, Zip::File::CREATE) do |zipfile|
        input_filenames.each do |filename|
          zipfile.add(filename, File.join(folder, filename))
        end
      end
      filepath
    end

    def create_s3_bucket
      s3_client.create_bucket(
        bucket: bucket_name,
        create_bucket_configuration: {
          location_constraint: region,
        },
      )
      bucket_policy = <<-EOS
{
  "Version": "2012-10-17",
  "Id": "allow access processed data",
  "Statement": [
    {
      "Sid": "allow access all",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::#{bucket_name}/*"
    }
  ]
}
      EOS
      s3_client.put_bucket_policy(
        bucket: bucket_name,
        policy: bucket_policy,
      )
    end

    def bucket_name
      @bucket_name ||= app_name.gsub('_', '-')
    end

    def update_s3_bucket_redirection
      s3_client.put_bucket_website(
        bucket: bucket_name,
        website_configuration: {
          index_document: {
            suffix: 'index.html',
          },
          routing_rules: [
            {
              condition: {
                http_error_code_returned_equals: '404',
              },
              redirect: {
                host_name: api_gateway_domain,
                http_redirect_code: '302',
                replace_key_prefix_with: "#{stage}/",
              },
            },
          ],
        },
      )
    end

    def build_lambda_role
      iam_client.get_role(role_name: "lambda-#{app_name}").role
    rescue Aws::IAM::Errors::NoSuchEntity
      role_policy_document = <<-EOS
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
      EOS
      role = iam_client.create_role(
        role_name: "lambda-#{app_name}",
        assume_role_policy_document: role_policy_document,
      ).role
      policy_document = <<-EOS
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "s3:PutObject",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketAcl",
          "s3:GetBucketCORS",
          "s3:GetBucketLocation",
          "s3:GetBucketLogging",
          "s3:GetBucketNotification",
          "s3:GetBucketPolicy",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketTagging",
          "s3:GetBucketVersioning",
          "s3:GetBucketWebsite",
          "s3:GetLifecycleConfiguration",
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:GetObjectTorrent",
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTorrent",
          "s3:GetReplicationConfiguration",
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucketVersions",
          "s3:ListMultipartUploadParts"
      ],
      "Resource": "arn:aws:s3:::#{bucket_name}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
      EOS
      iam_client.put_role_policy(
        role_name: role.role_name,
        policy_name: "lambda-#{app_name}-policy",
        policy_document: policy_document,
      )
      role
    end

    def build_api_gateway
      @api = api_gateway_client.create_rest_api(
        name: app_name,
      )
      root_resource = api_gateway_client.get_resources({
        rest_api_id: @api.id,
        limit: 1,
      }).items.first
      parameter_resource = api_gateway_client.create_resource(
        rest_api_id: @api.id,
        parent_id: root_resource.id,
        path_part: '{parameter}',
      )
      filename_resource = api_gateway_client.create_resource(
        rest_api_id: @api.id,
        parent_id: parameter_resource.id,
        path_part: '{filename}',
      )
      api_gateway_client.put_method(
        rest_api_id: @api.id,
        resource_id: filename_resource.id,
        http_method: 'GET',
        authorization_type: 'NONE',
      )
      json_template = <<-EOS
{
  "bucket_name": "#{bucket_name}",
  "parameter": "$input.params('parameter')",
  "filename": "$input.params('filename')"
}
      EOS
      api_gateway_client.put_integration(
        rest_api_id: @api.id,
        resource_id: filename_resource.id,
        http_method: 'GET',
        type: 'AWS',
        integration_http_method: 'POST',
        uri: "arn:aws:apigateway:#{region}:lambda:path/2015-03-31/functions/arn:aws:lambda:#{region}:#{aws_account_id}:function:#{app_name}/invocations",
        request_templates: {
          'application/json' => json_template,
        },
        passthrough_behavior: 'WHEN_NO_TEMPLATES',
      )
      api_gateway_client.put_method_response(
        rest_api_id: @api.id,
        resource_id: filename_resource.id,
        http_method: 'GET',
        status_code: '302',
        response_parameters: {
          'method.response.header.Location' => true,
        },
      )
      api_gateway_client.put_integration_response(
        rest_api_id: @api.id,
        resource_id: filename_resource.id,
        http_method: 'GET',
        status_code: '302',
        response_parameters: {
          'method.response.header.Location' => 'integration.response.body.location',
        },
      )

      lambda_client.add_permission(
        function_name: app_name,
        statement_id: SecureRandom.uuid,
        action: 'lambda:InvokeFunction',
        principal: 'apigateway.amazonaws.com',
        source_arn: "arn:aws:execute-api:#{region}:#{aws_account_id}:#{@api.id}/*/GET/{parameter}/{filename}",
      )

      api_gateway_client.create_deployment(
        rest_api_id: @api.id,
        stage_name: stage,
      )
    end

    def endpoint
      "http://#{bucket_name}.s3-website-#{region}.amazonaws.com/"
    end

    def api_gateway_domain
      "#{@api.id}.execute-api.ap-northeast-1.amazonaws.com"
    end

    def aws_account_id
      @aws_account_id ||= sts_client.get_caller_identity.account
    end

    def region
      @region ||= DEFAULT_REGION
    end

    def lambda_client
      @lambda_client ||= Aws::Lambda::Client.new(
        region:            region,
        access_key_id:     ENV['ACCESS_KEY_ID'],
        secret_access_key: ENV['SECRET_ACCESS_KEY'],
      )
    end

    def api_gateway_client
      @api_gateway_client ||= Aws::APIGateway::Client.new(
        region:            region,
        access_key_id:     ENV['ACCESS_KEY_ID'],
        secret_access_key: ENV['SECRET_ACCESS_KEY'],
      )
    end

    def sts_client
      @sts_client ||= Aws::STS::Client.new(
        region:            region,
        access_key_id:     ENV['ACCESS_KEY_ID'],
        secret_access_key: ENV['SECRET_ACCESS_KEY'],
      )
    end

    def iam_client
      @iam_client ||= Aws::IAM::Client.new(
        region:            region,
        access_key_id:     ENV['ACCESS_KEY_ID'],
        secret_access_key: ENV['SECRET_ACCESS_KEY'],
      )
    end

    def s3_client
      @s3_client ||= Aws::S3::Client.new(
        region:            region,
        access_key_id:     ENV['ACCESS_KEY_ID'],
        secret_access_key: ENV['SECRET_ACCESS_KEY'],
      )
    end

    def app_name
      @app_name ||= ENV['APP_NAME']
    end

    def stage
      @stage ||= DEFAULT_STAGE
    end
  end
end
