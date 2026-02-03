# Edugami Platform - AWS Infrastructure (Terraform)

Infraestructura como Código para desplegar Rails + Sidekiq en AWS ECS Fargate.

## Arquitectura

```
                    Internet
                        │
                   ┌────┴────┐
                   │   ALB   │  (Shared)
                   └────┬────┘
                        │
        ┌─────────────────────────┐
        │                         │
   dev.edugami.pro      prod.edugami.pro
        │                       |                       ▼
   ┌─────────┐             ┌─────────┐
   │ DEV TG  │             │ PROD TG │
   └────┬────┘             └────┬────┘
        │                       │
        ▼                       ▼
┌───────────────┐       ┌───────────────┐
│  DEV Services │       │ PROD Services │
│ ┌───────────┐ │       │ ┌───────────┐ │
│ │Web (Rails)│ │       │ │Web (Rails)│ │
│ │ On-Demand │ │       │ │ On-Demand │ │
│ └───────────┘ │       │ └───────────┘ │
│ ┌───────────┐ │       │ ┌───────────┐ │
│ │  Worker   │ │       │ │  Worker   │ │
│ │  (Spot)   │ │       │ │  (Spot)   │ │
│ └───────────┘ │       │ └───────────┘ │
│ ┌───────────┐ │       │ ┌───────────┐ │
│ │    RDS    │ │       │ │    RDS    │ │
│ └───────────┘ │       │ └───────────┘ │
│ ┌───────────┐ │       │ ┌───────────┐ │
│ │   Redis   │ │       │ │   Redis   │ │
│ └───────────┘ │       │ └───────────┘ │
└───────────────┘       └───────────────┘
        │                       │
        └───────────┬───────────┘
                    │
              ┌─────┴─────┐
              │ Shared VPC│
              │ (1 NAT GW)│
              └───────────┘
```

## Costos Estimados (USD/mes)

| Componente | DEV | PROD |
|------------|-----|------|
| NAT Gateway | $16 | $16 |
| ALB | $8 | $8 |
| ECS Web (On-Demand) | $9 | $37 |
| ECS Worker (Spot) | $3 | $11 |
| RDS PostgreSQL | $13 | $52 |
| ElastiCache Redis | $12 | $25 |
| **Total** | **~$63** | **~$154** |

## Prerequisitos

- AWS CLI configurado con credenciales apropiadas
- Terraform >= 1.5.0
- Docker
- Permisos de AWS para crear recursos (VPC, ECS, RDS, ElastiCache, ALB, etc.)

## Importante: Seguridad

**NUNCA** subas archivos con credenciales al repositorio:
- `*.tfvars` con passwords o secrets
- Archivos `.env`
- Claves SSH o certificados privados

El `.gitignore` ya está configurado para prevenir esto.

## Despliegue

### 1. Bootstrap (solo una vez)

Crear el bucket S3 y tabla DynamoDB para el estado de Terraform:

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

### 2. Infraestructura Compartida

```bash
cd terraform/shared
terraform init
terraform apply
```

**Importante:** Después de aplicar, ver los registros DNS para validar el certificado:

```bash
terraform output dns_validation_records
```

Crear los registros CNAME en tu proveedor DNS y esperar la validación (~5-30 min).

### 3. Build y Push de Docker Image

```bash
# Login a ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build (usar --platform linux/amd64 para Fargate)
docker build --platform linux/amd64 -t edugami:latest .

# Tag
docker tag edugami:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/edugami:latest

# Push
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/edugami:latest
```

### 4. DEV Environment

```bash
cd terraform/environments/dev
terraform init

# Aplicar con variables sensibles
terraform apply \
  -var="db_password=YOUR_DB_PASSWORD" \
  -var="rails_master_key=YOUR_MASTER_KEY"
```

### 5. PROD Environment

```bash
cd terraform/environments/prod
terraform init

terraform apply \
  -var="db_password=YOUR_DB_PASSWORD" \
  -var="rails_master_key=YOUR_MASTER_KEY"
```

## Variables Sensibles

**Método recomendado:** Usar variables de entorno para no exponer secretos:

```bash
export TF_VAR_db_password="your-secure-password"
export TF_VAR_rails_master_key="your-rails-master-key"
```

**Alternativa:** Crear un archivo `terraform.tfvars` (ya está en .gitignore):

```hcl
db_password       = "your-secure-password"
rails_master_key  = "your-rails-master-key"
```

**Para producción:** Considera usar AWS Secrets Manager o AWS Systems Manager Parameter Store.

## Estructura de Archivos

```
terraform/
├── bootstrap/           # S3 + DynamoDB para state
├── modules/
│   ├── network/         # VPC, subnets, NAT
│   ├── security/        # Security Groups
│   ├── alb/             # Load Balancer
│   ├── ecs-cluster/     # ECS Cluster
│   ├── ecr/             # Docker Registry
│   ├── acm/             # SSL Certificate
│   └── app-cluster/     # ECS + RDS + Redis
├── shared/              # Infraestructura compartida
└── environments/
    ├── dev/             # Configuración DEV
    └── prod/            # Configuración PROD
```

## Comandos Útiles

```bash
# Ver logs de ECS
aws logs tail /ecs/edugami-dev --follow

# Ejecutar comando en contenedor (debugging)
aws ecs execute-command \
  --cluster edugami-cluster \
  --task <task-id> \
  --container web \
  --interactive \
  --command "/bin/bash"

# Escalar servicio manualmente
aws ecs update-service \
  --cluster edugami-cluster \
  --service edugami-dev-web \
  --desired-count 2

# Ver estado de servicios
aws ecs describe-services \
  --cluster edugami-cluster \
  --services edugami-dev-web edugami-dev-worker

ó
aws ecs describe-services \
  --cluster edugami-cluster \
  --services edugami-dev-web edugami-dev-worker \
  --query 'services[*].[serviceName,runningCount,desiredCount,deployments[0].status,tasks[0].healthStatus]' \
  --output table
```

## DNS Configuration

Después de desplegar, crear estos registros DNS:

| Record | Type | Value |
|--------|------|-------|
| dev.edugami.pro | CNAME | <ALB_DNS_NAME> |
| edugami.pro | A/ALIAS | <ALB_DNS_NAME> |
| <www.edugami.pro> | CNAME | <ALB_DNS_NAME> |

## Security Groups

- **DEV DB** solo acepta tráfico de **DEV App**
- **PROD DB** solo acepta tráfico de **PROD App**
- No hay acceso cruzado entre ambientes

## Migraciones

aws ecs execute-command \
  --cluster edugami-cluster \
  --task $TASK_ID \
  --container web \
  --interactive \
  --command "bundle exec rake db:migrate"


# Jugar en la Terminal

TASK_ID=$(aws ecs list-tasks \
  --cluster edugami-cluster \
  --service-name edugami-dev-web \
  --desired-status RUNNING \
  --query 'taskArns[0]' \
  --output text | cut -d'/' -f3)

echo "Task ID: $TASK_ID"

aws ecs execute-command \
  --cluster edugami-cluster \
  --task $TASK_ID \
  --container web \
  --interactive \
  --command "/bin/bash"

## Troubleshooting

### Certificado SSL no se valida

```bash
# Ver estado del certificado
aws acm describe-certificate --certificate-arn <arn>

# Verificar registros DNS en Route53 o tu proveedor
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>
```

### Tareas de ECS no arrancan

```bash
# Ver eventos del servicio
aws ecs describe-services \
  --cluster edugami-cluster \
  --services edugami-dev-web \
  --query 'services[0].events[0:5]'

# Ver logs
aws logs tail /ecs/edugami-dev --follow
```

### Base de datos no es accesible

Verificar Security Groups:
```bash
aws ec2 describe-security-groups \
  --group-ids <db-security-group-id>
```

### Problemas con Docker build en Mac M1/M2

```bash
# Forzar plataforma linux/amd64
docker build --platform linux/amd64 -t edugami:latest .
```

## Destruir Infraestructura

**¡PRECAUCIÓN!** Esto eliminará todos los recursos. Los datos de RDS se perderán si no hay snapshots.

```bash
# Eliminar ambientes primero
cd environments/prod
terraform destroy

cd ../dev
terraform destroy

# Luego recursos compartidos
cd ../../shared
terraform destroy

# Finalmente bootstrap (si quieres eliminar el estado remoto)
cd ../bootstrap
terraform destroy
```

## CI/CD con GitHub Actions

Este repositorio incluye configuración para GitHub OIDC, permitiendo que GitHub Actions despliegue sin credenciales estáticas.

Configurar los siguientes secrets en GitHub:
- `AWS_ACCOUNT_ID`
- `DB_PASSWORD`
- `RAILS_MASTER_KEY`

## Monitoreo y Alertas

La infraestructura incluye:
- CloudWatch Logs para todos los servicios ECS
- Alarmas de CPU y memoria
- Dashboard de CloudWatch (si el módulo de monitoring está habilitado)
- WAF para protección contra ataques comunes

Ver logs en tiempo real:
```bash
aws logs tail /ecs/edugami-prod --follow --filter-pattern "ERROR"
```

## Backups

### RDS
- Backups automáticos configurados (retention period)
- Snapshots manuales recomendados antes de cambios mayores

```bash
aws rds create-db-snapshot \
  --db-instance-identifier edugami-prod \
  --db-snapshot-identifier edugami-prod-manual-$(date +%Y%m%d)
```

### Restaurar desde snapshot
```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier edugami-prod-restored \
  --db-snapshot-identifier <snapshot-id>
```