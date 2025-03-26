output api_endpoint {
  value       = aws_api_gateway_stage.api_stage.invoke_url
  description = "The API endpoint"
}

output api_name {
  value       = aws_api_gateway_stage.api_stage.arn
  description = "The API arn"
}