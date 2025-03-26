# ===================================================
## Variables Requeridas
## ===================================================

## Tags AWS
## ---------------------------------------------------

variable "common_tags" {
  type        = map(string)
  description = "Tags to be applied to all resources."
}

variable "region" {
  type        = string
  description = "API Gateway REST name"
  default	  = "clr-dom-apigateway-rest"
}

variable "account" {
  type        = string
  description = "API Gateway REST name"
  default	  = "clr-dom-apigateway-rest"
}

## S3 bucket
## ---------------------------------------------------

variable "api_name" {
  type        = string
  description = "API Gateway REST name"
  default	  = "apigateway-rest"
}

variable "description" {
  type        = string
  description = "Description of Apigateway"
  default	  = "API REST para interactuar con CLR DOM"
}

variable "proyect" {
  type        = string
  description = "Project Code, used as prefix to create resources"
  default	  = "clr-dom"
}

variable "stage" {
  type        = string
  description = "Stage del proyecto"
  default	  = "test"
}

variable "endpoint_type" {
  type        = list(string)
  description = "API Gateway REST name"
  default	  = ["REGIONAL"]
}

variable "force_redeploy" {
  type        = bool
  description = "Set true to force redeployment"
  default	  = false
}

variable "stage_name" {
  description = "Stage for deploy of apigateway"
  type = string
  default = "v1"
}

variable "cache_cluster_enabled" {
  description = "Flag for enable cluster cache"
  type = bool
  default = false
}

variable "cache_cluster_size" {
  description = "Size of cluster cache when cluster cache is enable"
  type = number
  default = 0
}

variable "authorizer" {
  description = "Authorizer List"
  type  = map(object({
    type            = string
    provider_arns   = list(string)
    identity_source = string
  }))
  default = {}
}

variable "dynamo_resources" {
  description = "Dynamo's Resource List"
  type = map(object({
    table_name = string
    index_name = optional(string)
    policy_action = string
    dynamo_action = string
    method_http_method = string
    use_authorizer                = bool
    method_request_parameters = optional(map(string), {})
    method_response_status_code   = string
    method_response_parameters = optional(map(string), {})
    integration_http_method       = string
    integration_type             = string
    integration_passthrough_behavior          = string
    integration_request_parameters = optional(map(string), {})
    request_template_type        = string
    request_template             = string
    integration_response_status_code = string
    integration_response_parameters = optional(map(string), {})
    response_template_type         = string
    response_template             = string
    cors_enable = bool
  }))
  default = {}
}

variable "lambda_resources" {
  description = "Lambda's Resource List"
  type = map(object({
    lambda_name = string
    cors_enable = bool
    parent_path = string
    path_part = string
    use_proxy = bool
    use_authorizer                = bool
    integration_type             = string
    integration_http_method       = string
    method_response_status_code   = string
    uri = string
    method_http_method = string
    method_request_parameters = optional(map(string), {})
    method_response_parameters = optional(map(string), {})
    integration_response_status_code = string
    integration_response_parameters = optional(map(string), {})
    api_key_required = bool
  }))
  default = {}
}

## ===================================================
## Variables Opcionales
## ===================================================

variable "custom_domain_arn" {
  description = "ARN del certificado ACM para el dominio personalizado. Si está vacío, no se creará el dominio."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain Name"
  type        = string
  default     = ""
}

variable "base_path" {
  description = "Path segment that must be prepended to the path when accessing the API via this mapping. If omitted, the API is exposed at the root of the given domain."
  type        = string
  default     = ""
}

variable "create_domain_name" {
  description = "Domain Name"
  type        = string
  default     = false
}


