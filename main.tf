resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.proyect}-${var.api_name}-${var.stage}"
  description = var.description
  tags   = var.common_tags
  endpoint_configuration {
    types            = var.endpoint_type
  }
}

resource "null_resource" "force_redeploy" {
  count = var.force_redeploy ? 1 : 0
  triggers = {
    always_run = timestamp()
  }
}

resource "aws_api_gateway_authorizer" "custom_authorizer" {
  for_each = var.authorizer
  name               = "${var.proyect}-${each.key}-authorizer-${var.stage}"
  type               = each.value.type
  provider_arns      = each.value.provider_arns
  identity_source    = each.value.identity_source
  rest_api_id        = aws_api_gateway_rest_api.api.id
}

resource "aws_iam_role" "api_gateway_role" {
  name = "${var.proyect}-${var.api_name}-execution-role-${var.stage}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "api_gateway_policy_dynamo" {
  count       = length(var.dynamo_resources) > 0 ? 1 : 0
  name = "${var.proyect}-${var.api_name}-dynamo-policy-${var.stage}"
  description = "Policy for API Gateway to interact with required services"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = distinct([
          for k, v in var.dynamo_resources : v.policy_action
        ]) # Extrae acciones únicas

        Resource = concat(
          [for v in values(var.dynamo_resources) : "arn:aws:dynamodb:${var.region}:${var.account}:table/${v.table_name}" if v.table_name != ""],
          [for v in values(var.dynamo_resources) : "arn:aws:dynamodb:${var.region}:${var.account}:table/${v.table_name}/index/${v.index_name}" if v.index_name != null]
        )
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_policy_attachment_dynamo" {
  count       = length(var.dynamo_resources) > 0 ? 1 : 0
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = aws_iam_policy.api_gateway_policy_dynamo[0].arn
}

resource "aws_api_gateway_resource" "dynamo_resources" {
  for_each   = var.dynamo_resources
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "${var.proyect}-${each.key}"
}

resource "aws_api_gateway_method" "dynamo_methods" {
  for_each    = var.dynamo_resources
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.dynamo_resources[each.key].id
  http_method = each.value.method_http_method
  authorization = each.value.use_authorizer ? var.authorizer.cognito_authorizer.type : "NONE"
  authorizer_id = each.value.use_authorizer ? aws_api_gateway_authorizer.custom_authorizer["cognito_authorizer"].id : null
  request_parameters = each.value.method_request_parameters
}

resource "aws_api_gateway_method_response" "dynamo_method_responses" {
  for_each    = var.dynamo_resources
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.dynamo_resources[each.key].id
  http_method = aws_api_gateway_method.dynamo_methods[each.key].http_method
  status_code = each.value.method_response_status_code
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = each.value.method_response_parameters
}

resource "aws_api_gateway_integration" "dynamo_integrations" {
  for_each    = var.dynamo_resources
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.dynamo_resources[each.key].id
  http_method = aws_api_gateway_method.dynamo_methods[each.key].http_method
  type                    = each.value.integration_type
  integration_http_method = each.value.integration_http_method
  passthrough_behavior    = each.value.integration_passthrough_behavior
  uri                     = "arn:aws:apigateway:${var.region}:dynamodb:action/${each.value.dynamo_action}"
  credentials             = aws_iam_role.api_gateway_role.arn
  request_parameters = each.value.integration_request_parameters
  request_templates = {
    (each.value.request_template_type) = each.value.request_template
  }
}

resource "aws_api_gateway_integration_response" "dynamo_integration_responses" {
  for_each    = var.dynamo_resources
  depends_on  = [aws_api_gateway_method_response.dynamo_method_responses]
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.dynamo_resources[each.key].id
  http_method = aws_api_gateway_method.dynamo_methods[each.key].http_method
  status_code = each.value.integration_response_status_code
  response_parameters = { for k, v in each.value.integration_response_parameters : k => "${v}" }
  response_templates = {
    (each.value.response_template_type) = each.value.response_template
  }
}

resource "aws_api_gateway_method" "dynamo_cors_methods" {
  for_each     = { for k, v in var.dynamo_resources : k => v if v.cors_enable }
  rest_api_id  = aws_api_gateway_rest_api.api.id
  resource_id  = aws_api_gateway_resource.dynamo_resources[each.key].id
  http_method  = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "dynamo_cors_method_responses" {
  for_each    = aws_api_gateway_method.dynamo_cors_methods
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.dynamo_resources[each.key].id
  http_method = aws_api_gateway_method.dynamo_cors_methods[each.key].http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "dynamo_cors_integrations" {
  for_each     = aws_api_gateway_method.dynamo_cors_methods
  rest_api_id  = aws_api_gateway_rest_api.api.id
  resource_id  = aws_api_gateway_resource.dynamo_resources[each.key].id
  http_method  = aws_api_gateway_method.dynamo_cors_methods[each.key].http_method
  type         = "MOCK"
  passthrough_behavior = "NEVER"
  request_templates = {
    "application/json" = <<EOF
{"statusCode": 200}
EOF
  }
}

resource "aws_api_gateway_integration_response" "dynamo_cors_integration_responses" {
  for_each     = aws_api_gateway_method.dynamo_cors_methods
  depends_on   = [aws_api_gateway_method_response.dynamo_cors_method_responses]
  rest_api_id  = aws_api_gateway_rest_api.api.id
  resource_id  = aws_api_gateway_resource.dynamo_resources[each.key].id
  http_method  = aws_api_gateway_method.dynamo_cors_methods[each.key].http_method
  status_code  = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
  }
}

resource "aws_api_gateway_resource" "lambda_parent_paths" {
  for_each   = { for k, v in var.lambda_resources : k => v if v.parent_path != "" }
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = each.value.parent_path
}

resource "aws_api_gateway_resource" "lambda_paths" {
  for_each    = var.lambda_resources
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id = lookup(
    aws_api_gateway_resource.lambda_parent_paths, 
    each.key, 
    aws_api_gateway_rest_api.api.root_resource_id
  ).id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_method" "lambda_methods" {
  for_each     = var.lambda_resources
  rest_api_id  = aws_api_gateway_rest_api.api.id
  resource_id  = aws_api_gateway_resource.lambda_paths[each.key].id
  http_method  = each.value.method_http_method
  authorization = each.value.use_authorizer ? var.authorizer.cognito_authorizer.type : "NONE"
  authorizer_id = each.value.use_authorizer ? aws_api_gateway_authorizer.custom_authorizer["cognito_authorizer"].id : null
  request_parameters = each.value.api_key_required ? each.value.method_request_parameters : {}
  api_key_required = each.value.api_key_required
}

resource "aws_lambda_permission" "apigw_lambda_permissions" {
  for_each      = var.lambda_resources
  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${var.region}:${var.account}:${aws_api_gateway_rest_api.api.id}/*/*"
}

resource "aws_api_gateway_integration" "lambda_integrations" {
  for_each    = var.lambda_resources
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.lambda_paths[each.key].id
  http_method = aws_api_gateway_method.lambda_methods[each.key].http_method
  type        = each.value.integration_type
  integration_http_method = each.value.integration_http_method
  uri         = each.value.uri
}

resource "aws_api_gateway_method_response" "lambda_method_responses" {
  for_each    = var.lambda_resources
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.lambda_paths[each.key].id
  http_method = aws_api_gateway_method.lambda_methods[each.key].http_method
  status_code = each.value.method_response_status_code
  response_parameters = each.value.cors_enable ? each.value.method_response_parameters : {}
}

resource "aws_api_gateway_integration_response" "lambda_integration_responses" {
  for_each    = var.lambda_resources
  depends_on = [aws_api_gateway_integration.lambda_integrations]
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.lambda_paths[each.key].id
  http_method = aws_api_gateway_method.lambda_methods[each.key].http_method
  status_code = each.value.integration_response_status_code
  response_parameters = each.value.cors_enable ? each.value.integration_response_parameters : {}
}

resource "aws_api_gateway_api_key" "lambda_api_key" {
  for_each    = { for k, v in var.lambda_resources : k => v if v.api_key_required }
  name = "${var.proyect}-${var.api_name}-${each.key}-apikey-${var.stage}"
  enabled = true
}

resource "aws_api_gateway_usage_plan" "lambda_usage_plan" {
  for_each    = { for k, v in var.lambda_resources : k => v if v.api_key_required }
  name        = "${var.proyect}-${var.api_name}-${each.key}-usage-plan-${var.stage}"
  description = "Usage plan for Lambda API"
  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.api_stage.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "lambda_usage_plan_key" {
  for_each    = { for k, v in var.lambda_resources : k => v if v.api_key_required }
  key_id        = aws_api_gateway_api_key.lambda_api_key[each.key].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.lambda_usage_plan[each.key].id
}

resource "aws_api_gateway_method" "lambda_cors_methods" {
  for_each    = { for k, v in var.lambda_resources : k => v if v.cors_enable }
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.lambda_paths[each.key].id
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "lambda_cors_method_responses" {
  for_each    = aws_api_gateway_method.lambda_cors_methods
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.dynamo_resources[each.key].id
  http_method = aws_api_gateway_method.lambda_cors_methods[each.key].http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration" "lambda_cors_integrations" {
  for_each    = aws_api_gateway_method.lambda_cors_methods
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.lambda_paths[each.key].id
  http_method = aws_api_gateway_method.lambda_cors_methods[each.key].http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = <<EOF
{"statusCode": 200}
EOF
  }
}

resource "aws_api_gateway_integration_response" "lambda_cors_integration_responses" {
  for_each    = aws_api_gateway_method.lambda_cors_methods
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.lambda_paths[each.key].id
  http_method = aws_api_gateway_method.lambda_cors_methods[each.key].http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
  }
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_resource.dynamo_resources,
    aws_api_gateway_method.dynamo_methods,
    aws_api_gateway_method_response.dynamo_method_responses,
    aws_api_gateway_integration.dynamo_integrations,
    aws_api_gateway_integration_response.dynamo_integration_responses,
    aws_api_gateway_method.dynamo_cors_methods,
    aws_api_gateway_method_response.dynamo_cors_method_responses,
    aws_api_gateway_integration.dynamo_cors_integrations,
    aws_api_gateway_integration_response.dynamo_cors_integration_responses,
    aws_api_gateway_resource.lambda_paths,
    aws_api_gateway_method.lambda_methods,
    aws_api_gateway_method_response.lambda_method_responses,
    aws_api_gateway_integration.lambda_integrations,
    aws_api_gateway_integration_response.lambda_integration_responses,
    aws_api_gateway_method.lambda_cors_methods,
    aws_api_gateway_method_response.lambda_cors_method_responses,
    aws_api_gateway_integration.lambda_cors_integrations,
    aws_api_gateway_integration_response.lambda_cors_integration_responses,
    null_resource.force_redeploy
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
  lifecycle {
    create_before_destroy = true
    replace_triggered_by = [
      aws_api_gateway_method.dynamo_methods,
      aws_api_gateway_method.lambda_methods,
      aws_api_gateway_integration.dynamo_integrations,
      aws_api_gateway_integration.lambda_integrations
    ]
  }
}

resource "aws_cloudwatch_log_group" "apigateway_log_group" {
  name              = "/aws/apigateway/${var.proyect}-${var.api_name}-${var.stage}"
  retention_in_days = 14
}

resource "aws_iam_role" "apigateway_cloudwatch_role" {
  name = "${var.proyect}-${var.api_name}-cloudwatch-role-${var.stage}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "apigateway_cloudwatch_policy" {
  name = "${var.proyect}-${var.api_name}-cloudwatch-policy-${var.stage}"
  role   = aws_iam_role.apigateway_cloudwatch_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_api_gateway_account" "account_settings" {
  cloudwatch_role_arn = aws_iam_role.apigateway_cloudwatch_role.arn
  depends_on = [aws_iam_role_policy.apigateway_cloudwatch_policy]
}

resource "aws_api_gateway_domain_name" "custom_domain" {
  count = var.custom_domain_arn != "" && var.create_domain_name ? 1 : 0
  domain_name              = var.domain_name
  regional_certificate_arn = var.custom_domain_arn
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "mapping" {
  count = var.custom_domain_arn != "" ? 1 : 0
  domain_name = var.domain_name
  api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api_stage.stage_name
  base_path = var.base_path
}

resource "aws_api_gateway_stage" "api_stage" {
  stage_name   = var.stage_name
  rest_api_id  = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  cache_cluster_enabled = var.cache_cluster_enabled
  cache_cluster_size    = var.cache_cluster_enabled ? tostring(var.cache_cluster_size) : null

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigateway_log_group.arn
    format          = jsonencode({
      requestId       = "$context.requestId",
      ip              = "$context.identity.sourceIp",
      caller          = "$context.identity.caller",
      user            = "$context.identity.user",
      requestTime     = "$context.requestTime",
      httpMethod      = "$context.httpMethod",
      resourcePath    = "$context.resourcePath",
      status          = "$context.status",
      responseLength  = "$context.responseLength"
    })
  }

  depends_on = [aws_api_gateway_account.account_settings]
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
	  data_trace_enabled = true
	  throttling_burst_limit = 5000
	  throttling_rate_limit = 10000
	  caching_enabled = true
	  cache_ttl_in_seconds = 3600
	  require_authorization_for_cache_control = true
	  unauthorized_cache_control_header_strategy = "FAIL_WITH_403"
  }
}


