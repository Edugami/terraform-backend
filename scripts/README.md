# Scripts de Utilidades ECS

Script para levantar contenedores ECS interactivos para ejecutar migraciones, debugging, rails console, y tareas de mantenimiento.

---

## Tabla de Contenidos

1. [Tareas On-Demand (Interactivas)](#tareas-on-demand-interactivas)
2. [Cronjobs con EventBridge](#cronjobs-con-eventbridge)
3. [Migración PostgreSQL Heroku → AWS RDS](#migración-postgresql-heroku--aws-rds-ecs-fargate)

---

## Tareas On-Demand (Interactivas)

### Script Automatizado

El script `run-ondemand-task.sh` levanta un contenedor Rails con `sleep infinity` y te conecta automáticamente:

```bash
./scripts/run-ondemand-task.sh dev
```

**¿Qué hace el script?**
1. Lee configuración de Terraform (subnets, security groups, task definition)
2. Ejecuta `aws ecs run-task` con `sleep infinity` y `--enable-execute-command`
3. Espera a que la task esté corriendo
4. Conecta automáticamente vía `aws ecs execute-command` a bash

### Dentro del Contenedor

Una vez conectado, tienes acceso completo a Rails:

```bash
# Rails console
bundle exec rails console

# Ejecutar migración
bundle exec rake db:migrate

# Rollback
bundle exec rake db:rollback

# Seeds
bundle exec rake db:seed

# Rails runner
bundle exec rails runner "puts User.count"

# Conectar a PostgreSQL directamente
psql $DATABASE_URL

# Ver secrets
echo $DATABASE_URL
echo $REDIS_URL
echo $RAILS_MASTER_KEY

# Salir
exit
```

**El contenedor sigue corriendo** hasta que lo detengas manualmente o alcance el timeout (10 horas). Esto evita problemas con health checks y te da tiempo para ejecutar múltiples comandos.

### Ver Logs

```bash
# Logs en tiempo real
aws logs tail /ecs/edugami-dev/ondemand --follow

# Logs recientes
aws logs tail /ecs/edugami-dev/ondemand --since 2h
```

### Detener el Contenedor

```bash
# Listar tareas corriendo
aws ecs list-tasks --cluster edugami-cluster --desired-status RUNNING

# Detener una tarea específica
aws ecs stop-task --cluster edugami-cluster --task <TASK_ARN>
```

### Troubleshooting

#### No se puede conectar vía ECS Exec

1. Verificar que la task tiene `--enable-execute-command` (el script lo hace automáticamente)
2. Verificar permisos IAM del task role
3. Intentar nuevamente (a veces tarda unos segundos en estar listo)

#### Task se detiene sola

El `sleep infinity` mantiene el contenedor corriendo. Si se detiene, verificar:
- CloudWatch Logs para ver errores
- Que la imagen Docker sea correcta
- Que las variables de entorno (DATABASE_URL, etc.) estén en SSM

---

## Cronjobs con EventBridge

Usa EventBridge Scheduler para ejecutar tareas Rails en horarios específicos. Los cronjobs reutilizan la misma task definition `ondemand` con command override.

### Obtener Valores para EventBridge UI

Necesitas estos valores de Terraform para configurar los schedules:

```bash
cd environments/dev  # o prod
terraform output ondemand_task_definition_arn  # ARN de la task
terraform output private_app_subnet_ids        # Subnets
terraform output app_security_group_id         # Security group
```

### Crear Schedule en AWS Console

#### 1. Abrir EventBridge Scheduler
- AWS Console → EventBridge → **Schedules** → Create schedule

#### 2. Schedule Pattern
- **Name**: `edugami-dev-reports-daily`
- **Schedule type**: Recurring schedule
- **Cron expression**: `0 6 * * ? *` (6 AM UTC diario)

**Ejemplos de cron:**
- `0 6 * * ? *` - Diario 6 AM UTC
- `0 * * * ? *` - Cada hora
- `0 9 ? * MON-FRI *` - Lunes a Viernes 9 AM
- `0 3 ? * SUN *` - Domingos 3 AM
- `0 2 1 * ? *` - Primer día del mes 2 AM

#### 3. Target (RunTask)
- **API**: Amazon ECS
- **ECS cluster**: `arn:aws:ecs:us-east-1:975363676135:cluster/edugami-cluster`
- **ECS task**: Pegar el ARN de `terraform output ondemand_task_definition_arn`
- **Launch type**: FARGATE_SPOT (ahorra 70%) o FARGATE

#### 4. Compute Options
- **Launch type**: FARGATE_SPOT (recomendado) o FARGATE
- **Platform version**: LATEST

#### 5. Network Configuration
- **Subnets**: Pegar valores de `terraform output private_app_subnet_ids`
- **Security groups**: Pegar valor de `terraform output app_security_group_id`
- **Public IP**: DISABLED

#### 6. Container Overrides
- **Container name**: `ondemand`
- **Command override**: `bin/rails,runner,ReportGenerator.generate_daily`
  - ⚠️ **Importante**: Separar con **comas**, NO espacios
  - Ejemplo: `bundle,exec,rake,db:seed`

#### 7. Settings
- **State**: Enabled
- **Retry attempts**: 2

### Ver Schedules

```bash
# Listar schedules
aws scheduler list-schedules --name-prefix edugami-dev

# Ver detalles
aws scheduler get-schedule --name edugami-dev-reports-daily
```

### Ver Logs de Ejecuciones

```bash
# Los cronjobs usan el mismo log group que on-demand
aws logs tail /ecs/edugami-dev/ondemand --follow
aws logs tail /ecs/edugami-dev/ondemand --since 2h
```

### Ejemplos de Cronjobs

| Descripción | Cron | Command Override |
|-------------|------|------------------|
| Reporte diario | `0 6 * * ? *` | `bin/rails,runner,ReportGenerator.generate_daily` |
| Limpieza semanal | `0 3 ? * SUN *` | `bin/rails,runner,CleanupJob.perform` |
| Backup mensual | `0 2 1 * ? *` | `bin/rails,runner,BackupJob.perform` |
| Cada hora | `0 * * * ? *` | `bin/rails,runner,SyncJob.perform` |

### Troubleshooting Cronjobs

**Schedule no se ejecuta:**
1. Verificar que está ENABLED en EventBridge
2. Verificar expresión cron (usa UTC)
3. Ver logs: `aws logs tail /ecs/edugami-dev/ondemand --since 1h`

**Task falla:**
1. Probar el comando manualmente primero:
   ```bash
   ./scripts/run-ondemand-task.sh dev
   # Dentro ejecutar: bin/rails runner ReportGenerator.generate_daily
   ```
2. Verificar que el command override usa comas (no espacios)
3. Verificar subnets y security groups correctos

### Costos Estimados

**On-Demand Task** (1 vCPU, 2 GB):
- Uso interactivo esporádico: <$1/mes por ambiente
- 1 hora corriendo: ~$0.06 (FARGATE)

**Cronjobs** (reutiliza misma task 1 vCPU, 2 GB):
- 10 minutos/día con FARGATE: ~$1/mes
- 10 minutos/día con FARGATE_SPOT: ~$0.30/mes (70% ahorro)

**Recomendación**: Usa FARGATE_SPOT para cronjobs (más barato y toleran interrupciones).

---

## Migración PostgreSQL Heroku → AWS RDS (ECS Fargate)

Objetivo

Restaurar un dump de PostgreSQL (Heroku) en una base RDS privada usando una tarea ECS Fargate dedicada, sin afectar servicios ni health checks.

## 1.- Requisitos previos

- Dump en formato custom (pg_dump -Fc)
  - Dump de Heroku
  
```curl
  heroku pg:backups:url b<ID> --app edugami-platform-development
```

- RDS accesible solo desde VPC
- Cluster ECS existente (Fargate)  
- Subnets privadas y SG con acceso a RDS:5432
- AWS CLI configurado

## 2. IAM Roles (CRÍTICO)

### 2.1 Execution Role (para ECS)

Rol: edugami-dev-ecs-execution-role
Trusted entity:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ecs-tasks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Policies mínimas:

- AmazonECSTaskExecutionRolePolicy (si usas logs)
- logs:CreateLogGroup
- logs:CreateLogStream
- logs:PutLogEvents

### 2.2 Task Role (para el container)

Rol: edugami-dev-ecs-task-role

Si solo usas presigned URL, no necesita permisos extra.
(Si usaras S3 directo → s3:GetObject)

## 3. Crear Log Group (opcional pero recomendado)

```bash
aws logs create-log-group \
  --region us-east-1 \
  --log-group-name /ecs/edugami-restore

aws logs put-retention-policy \
  --region us-east-1 \
  --log-group-name /ecs/edugami-restore \
  --retention-in-days 3
```

## 4. Task Definition (JSON)

Crear el servicio si este no existe (En teoría ya está en amazon!)

```json
{
  "family": "edugami-restore-runner",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "4096",
  "executionRoleArn": "arn:aws:iam::<AWS_ACCOUNT_ID>:role/edugami-<ENV>-ecs-execution-role",
  "taskRoleArn": "arn:aws:iam::<AWS_ACCOUNT_ID>:role/edugami-<ENV>-ecs-task-role",
  "containerDefinitions": [
    {
      "name": "restore",
      "image": "postgres:16",
      "essential": true,
      "command": ["bash","-lc","sleep 36000"],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/edugami-restore",
          "awslogs-region": "<AWS_REGION>",
          "awslogs-stream-prefix": "restore"
        }
      }
    }
  ]
}
```

> **Note:** Replace placeholders:
> - `<AWS_ACCOUNT_ID>`: Your AWS account ID (e.g., `123456789012`)
> - `<ENV>`: Environment (`dev` or `prod`)
> - `<AWS_REGION>`: AWS region (e.g., `us-east-1`)

Registrar en Amazon

```bash
aws ecs register-task-definition \
  --cli-input-json file://restore-task.json
```

## 5. Ejecutar la Task (run-task)

First, set the network configuration variables (get these from Terraform outputs or AWS Console):

```bash
# Get these values from: cd terraform/shared && terraform output
export SUBNET_ID_1="<PRIVATE_SUBNET_ID_1>"   # e.g., subnet-0abc123...
export SUBNET_ID_2="<PRIVATE_SUBNET_ID_2>"   # e.g., subnet-0def456...
export SECURITY_GROUP_ID="<APP_SECURITY_GROUP_ID>"  # e.g., sg-0abc123...
```

Then run the task:

```bash
TASK_ARN=$(aws ecs run-task \
  --cluster edugami-cluster \
  --launch-type FARGATE \
  --task-definition edugami-restore-runner \
  --enable-execute-command \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID_1,$SUBNET_ID_2],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=DISABLED}" \
  --query 'tasks[0].taskArn' \
  --output text)

echo $TASK_ARN
```

> **Tip:** You can get network IDs from Terraform:
> ```bash
> cd terraform/shared
> terraform output private_app_subnet_ids  # For subnets
> terraform output app_dev_sg_id           # For security group (dev)
> ```

## 6. Entrar a la task

```bash
aws ecs execute-command \
  --cluster edugami-cluster \
  --task $TASK_ARN \
  --container restore \
  --interactive \
  --command "/bin/bash"
```

## 7. Descargar el dump creado por Heroku (presigned URL)

Dentro del container:

```bash
export PRESIGNED_URL="https://....s3.amazonaws.com/...dump?X-Amz-..."

apt update
apt install -y curl

apt install tmux

curl -L "$PRESIGNED_URL" -o /tmp/backup.dump
```

## 8. Restaurar en RDS

```bash
export DATABASE_URL="postgresql://user:pass@host:5432/dbname?sslmode=require"

export DB_USER=$(echo "$DATABASE_URL" | sed -E 's|.*://([^:]+):.*|\1|')
export DB_PASS=$(echo "$DATABASE_URL" | sed -E 's|.*://[^:]+:([^@]+)@.*|\1|')
export DB_HOST=$(echo "$DATABASE_URL" | sed -E 's|.*@([^:/?]+).*|\1|')
export DB_PORT=$(echo "$DATABASE_URL" | sed -E 's|.*:([0-9]+)/.*|\1|' || echo "5432")
export DB_NAME=$(echo "$DATABASE_URL" | sed -E 's|.*/([^?]+).*|\1|')
export PGPASSWORD="$DB_PASS"
```

PD: Si queremos borrar la BD debemos usar 

```
dropdb -h "$DB_HOST" -U "$DB_USER" "$DB_NAME"
createdb -h "$DB_HOST" -U "$DB_USER" "$DB_NAME"
```

Luego intentamos restaurar

```bash
pg_restore --verbose --clean --no-owner --no-acl --jobs 4 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" /tmp/backup.dump 2>&1 | tee restore_output.log
```

Para ver los output


```bash
tail restore_output.log
```

Notas:

- `--jobs` solo funciona con dumps -fc
- errors ignored on restore es normal en Rails (FKs, extensions, etc.)

## 9. Verificar

- Ver Schemas, cantidad, etc

## 10. Finalizar

Cuando termine:

- Detén la task desde la consola
- Deja que termine el sleep y se mate sola
