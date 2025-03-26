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
  common

