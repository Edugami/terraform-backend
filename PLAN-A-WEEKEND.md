# Plan A — Migrar cluster de prod a su propio state y renombrarlo

## Contexto

Actualmente el ECS Cluster de prod (`edugami-cluster`) vive en el state de `shared/`.
Este plan lo mueve al state de `environments/prod/` y lo renombra a `edugami-prod-cluster`.

> **RDS, Redis, ECR, ALB, VPC no se tocan. Solo se mueve/recrea el ECS Cluster.**

---

## Paso 1 — Cambios de código en `environments/prod/main.tf`

Agregar el módulo de cluster dedicado (igual que se hizo en dev):

```hcl
# ============================================================================
# PROD ECS Cluster (dedicated, isolated from dev)
# ============================================================================

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  project_name              = "${var.project_name}-${var.environment}"
  enable_container_insights = true
}
```

Cambiar en `module "app_cluster"`:

```hcl
# Antes:
ecs_cluster_id     = data.terraform_remote_state.shared.outputs.ecs_cluster_id
ecs_cluster_name   = data.terraform_remote_state.shared.outputs.ecs_cluster_name

# Después:
ecs_cluster_id     = module.ecs_cluster.cluster_id
ecs_cluster_name   = module.ecs_cluster.cluster_name
```

---

## Paso 2 — Cambios de código en `shared/main.tf`

Eliminar el bloque `module "ecs_cluster"`:

```hcl
# ELIMINAR todo este bloque:
module "ecs_cluster" {
  source = "../modules/ecs-cluster"
  ...
}
```

Actualizar `shared/main.tf` → el módulo `github_oidc` recibe `ecs_cluster_arn`.
Como prod tendrá su propio cluster, pasar una lista de ARNs o hardcodear el de prod.
**Revisar este punto antes de aplicar.**

Eliminar de `shared/outputs.tf` los outputs:
- `ecs_cluster_id`
- `ecs_cluster_name`
- `ecs_cluster_arn`

---

## Paso 3 — Migración de state (sin downtime en prod... hasta el rename)

### 3a. Backup de los states actuales

```bash
cd /ruta/al/repo/terraform-backend

# Backup shared state
cd shared
terraform state pull > /tmp/backup-shared-state-$(date +%Y%m%d).json

# Backup prod state
cd ../environments/prod
terraform state pull > /tmp/backup-prod-state-$(date +%Y%m%d).json
```

### 3b. Remover el cluster del state de shared (ya no lo maneja shared)

```bash
cd shared
terraform state rm module.ecs_cluster.aws_ecs_cluster.main
terraform state rm module.ecs_cluster.aws_ecs_cluster_capacity_providers.main
```

### 3c. Aplicar shared/ con el módulo ya eliminado del código

```bash
cd shared
terraform plan   # debe mostrar 0 cambios destructivos en otros recursos
terraform apply
```

### 3d. Aplicar prod/ — esto CREA el nuevo cluster `edugami-prod-cluster`

```bash
cd environments/prod
terraform init
terraform plan   # revisar: debe crear el nuevo cluster + recrear los ECS services apuntando al nuevo cluster
terraform apply
```

> ⚠️ **Aquí hay un breve downtime en prod** mientras los ECS services se recrean apuntando al nuevo cluster.
> El tiempo de downtime es el startup time de Rails (~2 min).
> **RDS y Redis NO se tocan.**

### 3e. Verificar que los services están corriendo en el nuevo cluster

```bash
aws ecs list-services --cluster edugami-prod-cluster
aws ecs describe-services \
  --cluster edugami-prod-cluster \
  --services edugami-prod-web edugami-prod-worker
```

### 3f. Eliminar el cluster viejo `edugami-cluster` (ya no tiene services)

```bash
aws ecs delete-cluster --cluster edugami-cluster
```

---

## Paso 4 — Resultado final

| Antes | Después |
|---|---|
| `edugami-cluster` (shared, dev+prod) | `edugami-dev-cluster` (solo dev) |
| — | `edugami-prod-cluster` (solo prod) |

Comandos sin ambigüedad:

```bash
# Dev
aws ecs execute-command --cluster edugami-dev-cluster ...

# Prod
aws ecs execute-command --cluster edugami-prod-cluster ...
```

---

## Rollback

Si algo sale mal antes del `terraform apply` en prod:

```bash
# Restaurar shared state desde backup
cd shared
terraform state push /tmp/backup-shared-state-YYYYMMDD.json
```

Si el apply de prod falla a mitad:

```bash
# El cluster viejo fue eliminado del state de shared pero no de AWS.
# Importarlo de vuelta al shared state:
cd shared
terraform import module.ecs_cluster.aws_ecs_cluster.main edugami-cluster
terraform import module.ecs_cluster.aws_ecs_cluster_capacity_providers.main edugami-cluster
```
