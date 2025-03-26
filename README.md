# Terraform API Gateway REST Module

## Descripción
Este módulo de Terraform crea una API Gateway REST en AWS con integración a Lambda y DynamoDB. Soporta autenticación con authorizers, configuración de caché, CORS, uso de API Keys y dominios personalizados.

## Recursos Implementados
- **API Gateway REST API** con configuración personalizada.
- **Authorizers** para autenticación.
- **Métodos y recursos** para DynamoDB y Lambda.
- **Integraciones** con AWS Lambda y DynamoDB.
- **Manejo de CORS** en los endpoints.
- **Uso de API Keys** con planes de uso.
- **Roles IAM** para API Gateway.
- **Dominios personalizados** para la API Gateway.

## Variables de Entrada

### Variables Requeridas
- `common_tags` *(map(string))*: Tags comunes para los recursos.
- `region` *(string)*: Región AWS.
- `account` *(string)*: ID de la cuenta AWS.
- `api_name` *(string)*: Nombre de la API.
- `description` *(string)*: Descripción de la API.
- `project` *(string)*: Código del proyecto.
- `stage` *(string)*: Etapa del despliegue (ej. `test`, `prod`).
- `endpoint_type` *(list(string))*: Tipo de endpoint (ej. `REGIONAL`).
- `force_redeploy` *(bool)*: Forzar redeployment.
- `stage_name` *(string)*: Nombre del stage de despliegue.
- `cache_cluster_enabled` *(bool)*: Activar caché.
- `cache_cluster_size` *(number)*: Tamaño del caché.
- `authorizer` *(map(object))*: Lista de authorizers.
- `dynamo_resources` *(map(object))*: Configuración de recursos DynamoDB.
- `lambda_resources` *(map(object))*: Configuración de recursos Lambda.
- `custom_domain` *(map(object))*: Configuración de dominios personalizados.

## Uso
Ejemplo de uso del módulo:

```hcl
module "api_gateway" {
  source        = "./modules/apigateway"
  common_tags   = { Environment = "dev" }
  region        = "us-east-1"
  account       = "123456789012"
  api_name      = "my-api"
  description   = "API Gateway para mi aplicación"
  project       = "my-project"
  stage         = "dev"
  endpoint_type = ["REGIONAL"]
  force_redeploy = true
  authorizer = {
    cognito_authorizer = {
      type             = "COGNITO_USER_POOLS"
      provider_arns    = ["arn:aws:cognito-idp:region:cuenta:userpool/id-user-pool"]
      identity_source  = "method.request.header.Authorization"
    }
  }
  dynamo_resources = {
    dynamo_table = {
      table_name                   = "tabla_name"
      index_name                   = "index_name"
      policy_action                = "dynamodb:Query"
      dynamo_action                = "Query"
      method_http_method           = "GET"
      use_authorizer               = true
      method_response_status_code  = "200"
      method_response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
      }
      integration_http_method      = "POST"
      integration_type             = "AWS"
      integration_passthrough_behavior = "NEVER"
      request_template_type        = "application/json"
      request_template             = <<EOF
{
  "TableName": "tabla_name",
  "KeyConditionExpression": "key = :value",
  "ExpressionAttributeValues": {
    ":value": { "S": "some value" }},
  "IndexName": "index_name"
}
EOF
      integration_response_status_code = "200"
      integration_response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = "'*'"
      }
      response_template_type = "application/json"
      response_template = <<EOF
#set($error = $input.path('$.__type'))
#set($count = $input.path('$.Count'))
#set($requestId = $context.requestId)
#set($integrationError = $context.integrationErrorMessage)
#if($error.toString() != "")
  #set($context.responseOverride.status = 400)
  {
    "message": "Hubo un error en la solicitud. Verifica los datos enviados.",
    "errorType": "$input.path('$.__type')",
    "requestId": "$requestId",
    "integrationError": "$integrationError"
  }
#elseif ($count.toString().equals("0"))
  #set($context.responseOverride.status = 400)
  {
    "message": "No existen datos asociados para esta consulta. Verifica los datos enviados.",
    "count": "$count",
    "requestId": "$requestId"
  }
#else
  #set($inputRoot = $input.path('$'))
  [
  #foreach($item in $inputRoot.Items)
    "$item.identifier.S"#if($foreach.hasNext),#end
  #end
  ]
#end
EOF
      cors_enable = true
    }
  }
  lambda_resources = {
    example_lambda = {
      lambda_name              = "my_lambda_function"
      cors_enable              = true
      parent_path              = "example"
      path_part                = "lambda"
      use_proxy                = true
      use_authorizer           = false
      integration_type         = "AWS_PROXY"
      integration_http_method  = "POST"
      uri                      = "arn:aws:apigateway:region:lambda:path/2015-03-31/functions/arn:aws:lambda:region:cuenta:function:my_lambda_function/invocations"
      method_http_method       = "POST"
      method_response_status_code = "200"
      api_key_required         = false
    }
  }
}
```

## Notas
- Para habilitar CORS, se debe configurar `cors_enable` en `true` en los recursos.
- Para usar API Keys, establecer `api_key_required = true` en los recursos Lambda.
- Para la autenticación, definir los `authorizer` con su tipo y configuración adecuada.

## Requerimientos
- Terraform `>= 1.0`
- AWS Provider `>= 4.0`
