# Migración PostgreSQL Heroku → AWS RDS (ECS Fargate)

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

Luego intentamos restaurar

```bash
pg_restore --verbose --clean --no-owner --no-acl --jobs 4 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" /tmp/backup.dump 2>&1 | tee restore_output.log
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
