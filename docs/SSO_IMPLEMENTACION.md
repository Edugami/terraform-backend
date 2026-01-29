# Implementación de AWS SSO (IAM Identity Center)

**Plan de Migración: IAM Users → AWS SSO**

---

## Estado de Implementación

✅ **FASE 2 COMPLETADA**: Módulos Terraform Creados

### Archivos Creados

```
terraform-backend/
├── modules/
│   └── sso-identity-center/          ✅ NUEVO
│       ├── main.tf                   ✅ 100 líneas - Módulo SSO completo
│       ├── variables.tf              ✅ Variables con validación
│       └── outputs.tf                ✅ Outputs incluye SSO start URL
├── environments/
│   ├── dev/
│   │   └── sso-users.tf             ✅ Configuración DEV (claguirre)
│   └── prod/
│       └── sso-users.tf             ✅ Configuración PROD (lista vacía)
└── docs/
    ├── SSO_GUIA_USUARIO.md          ✅ Guía completa en español
    └── SSO_IMPLEMENTACION.md        📄 Este archivo
```

---

## Próximos Pasos

### FASE 1: Configuración Manual (Ejecutar ANTES de terraform apply)

Esta fase es **MANUAL** porque IAM Identity Center no puede ser completamente automatizado en Terraform 5.0.

#### 1.1 Habilitar AWS Organizations

```bash
# Verificar estado
aws organizations describe-organization

# Si devuelve error, habilitar en consola:
# https://console.aws.amazon.com/organizations/
# Click "Create organization" → "All features"
```

#### 1.2 Habilitar IAM Identity Center

```bash
# Verificar si está habilitado
aws sso-admin list-instances --region us-east-1

# Si devuelve lista vacía [], habilitar en consola:
# https://console.aws.amazon.com/singlesignon/
# 1. Click "Enable"
# 2. Region: us-east-1
# 3. Identity source: "Identity Center directory"
```

#### 1.3 Capturar IDs (Para Verificación)

```bash
# Obtener SSO Instance ARN y Identity Store ID
aws sso-admin list-instances --region us-east-1

# Guardar el output para comparar con outputs de Terraform después
# Ejemplo de output:
# {
#   "Instances": [{
#     "InstanceArn": "arn:aws:sso:::instance/sso-instance/ins-abc123",
#     "IdentityStoreId": "d-abc123xyz"
#   }]
# }
```

#### 1.4 Crear Usuario SSO: claguirre

**Opción A: Via Consola (RECOMENDADO para primer usuario)**

1. Ir a: https://console.aws.amazon.com/singlesignon/
2. Click "Users" → "Add user"
3. Llenar formulario:
   - Username: `claguirre`
   - Email: `carlos@edugami.pro` (o tu email)
   - First name: `Carlos`
   - Last name: `Laguirre`
   - Display name: `Carlos Laguirre`
4. Click "Add user"
5. Usuario recibe email: "Invitation to join AWS Single Sign-On"

**Opción B: Via AWS CLI**

```bash
# Obtener Identity Store ID
IDENTITY_STORE_ID=$(aws sso-admin list-instances --region us-east-1 \
  --query 'Instances[0].IdentityStoreId' --output text)

# Crear usuario
aws identitystore create-user \
  --identity-store-id $IDENTITY_STORE_ID \
  --user-name claguirre \
  --display-name "Carlos Laguirre" \
  --emails Value=carlos@edugami.pro,Primary=true \
  --name Formatted="Carlos Laguirre",FamilyName=Laguirre,GivenName=Carlos \
  --region us-east-1
```

**Verificar usuario creado:**

```bash
aws identitystore list-users \
  --identity-store-id $IDENTITY_STORE_ID \
  --region us-east-1
```

---

### FASE 3: Aplicar Terraform

Una vez completada la **Fase 1**, ejecutar:

```bash
cd environments/dev

# Inicializar módulo nuevo
terraform init

# Revisar cambios
terraform plan

# Verificar que mostrará:
# + module.sso_readonly.aws_ssoadmin_permission_set.readonly
# + module.sso_readonly.aws_ssoadmin_customer_managed_policy_attachment.readonly_policy
# + module.sso_readonly.aws_ssoadmin_account_assignment.user_assignments["claguirre"]

# Aplicar
terraform apply

# Copiar el SSO Start URL del output
terraform output sso_readonly_info
```

**Output Esperado:**

```json
{
  "permission_set_name": "edugami-dev-readonly",
  "assigned_users": ["claguirre"],
  "session_duration": "PT8H",
  "sso_start_url": "https://d-abc123xyz.awsapps.com/start",
  "aws_account_id": "123456789012",
  "cli_setup_command": "aws configure sso",
  "login_command": "aws sso login --profile edugami-dev"
}
```

---

### FASE 4: Configuración del Usuario

#### 4.1 Usuario Configura Contraseña

1. Usuario (claguirre) revisa email: "Invitation to join AWS Single Sign-On"
2. Click en link para configurar contraseña
3. Configurar MFA (recomendado)
4. Anotar el SSO Start URL del email

#### 4.2 Usuario Configura AWS CLI

Ver guía completa en: [SSO_GUIA_USUARIO.md](./SSO_GUIA_USUARIO.md)

**Resumen rápido:**

```bash
# Verificar AWS CLI v2
aws --version  # Debe ser 2.x.x

# Configurar SSO
aws configure sso
# Responder con el SSO Start URL del output de Terraform

# Primer login
aws sso login --profile edugami-dev

# Verificar identidad
aws sts get-caller-identity --profile edugami-dev
```

#### 4.3 Testing de Permisos

```bash
# Configurar perfil
export AWS_PROFILE=edugami-dev

# ✅ Debe funcionar (lectura)
aws ecs describe-clusters --cluster edugami-dev-cluster
aws logs tail /ecs/edugami-dev-web --since 10m

# ❌ Debe fallar (escritura)
aws ecs update-service \
  --cluster edugami-dev-cluster \
  --service edugami-dev-web \
  --desired-count 2
# Error esperado: AccessDenied
```

---

### FASE 5: Estrategia de Migración

**Operación en Paralelo (Sin Downtime)**

#### Timeline Recomendado:

**Semanas 1-2: Testing Paralelo**
- ✅ Módulo `readonly-users` ACTIVO (IAM user claguirre)
- ✅ Módulo `sso_readonly` ACTIVO (SSO user claguirre)
- Usuario tiene ambos métodos de acceso
- Testing exhaustivo con SSO

**Semana 3: Migración Completa**
- Usuario confirma SSO funciona al 100%
- Actualizar scripts y documentación para usar SSO
- Deshabilitar console access de IAM users:

```hcl
# En environments/dev/readonly-users.tf
module "readonly_users" {
  # ...
  enable_console_access = false  # ← Cambiar a false
}
```

**Semana 4: Cleanup (Opcional)**
- Remover bloque `module "readonly_users"` de `readonly-users.tf`
- **IMPORTANTE**: NO borrar `modules/readonly-users/main.tf`
- **CRÍTICO**: Mantener políticas IAM porque SSO las referencia

---

## Arquitectura Implementada

```
AWS Account (Edugami)
│
├── AWS Organizations ────────────────────┐
│                                          │
├── IAM Identity Center (us-east-1) ◄─────┤ (Manual: Fase 1)
│   │                                      │
│   ├── Identity Store                    │
│   │   └── Users                          │
│   │       └── claguirre ◄────────────────┤ (Manual: Fase 1.4)
│   │           └── Email: carlos@edugami.pro
│   │
│   └── Permission Sets ◄──────────────────┤ (Terraform: Fase 3)
│       │
│       ├── edugami-dev-readonly           │
│       │   ├── Duration: PT8H             │
│       │   ├── Attached Policy:           │
│       │   │   └── edugami-dev-readonly-policy (Customer Managed)
│       │   └── Assigned Users:            │
│       │       └── claguirre              │
│       │
│       └── edugami-prod-readonly          │
│           ├── Duration: PT8H             │
│           ├── Attached Policy:           │
│           │   └── edugami-prod-readonly-policy (Customer Managed)
│           └── Assigned Users: []         │
│
└── IAM Policies (Creadas por readonly-users module)
    ├── edugami-dev-readonly-policy ◄──────┤ (Existente, reutilizada)
    └── edugami-prod-readonly-policy ◄─────┘ (Existente, reutilizada)
```

**Flujo de Acceso:**

```
Usuario (claguirre)
    │
    ├─→ Browser: https://d-abc123xyz.awsapps.com/start
    │       ↓
    │   IAM Identity Center
    │       ↓
    │   Autenticación (password + MFA)
    │       ↓
    │   AssumeRole con Permission Set
    │       ↓
    │   Credenciales Temporales (válidas 8h)
    │       ↓
    └─→ AWS CLI con credenciales temporales
            ↓
        Acceso Read-Only a recursos
```

---

## Diferencias Clave: IAM Users vs SSO

| Componente | IAM Users | AWS SSO |
|------------|-----------|---------|
| **Autenticación** | Access Key ID + Secret | Browser-based OAuth |
| **Credenciales** | Permanentes | Temporales (8h) |
| **Almacenamiento** | `~/.aws/credentials` | Cache temporal en `~/.aws/sso/` |
| **Login** | Una vez | Cada 8 horas |
| **Rotación** | Manual | Automática |
| **Multi-cuenta** | Keys por cuenta | Un login, múltiples cuentas |
| **MFA** | Por usuario | Centralizado en Identity Center |
| **Gestión** | `aws iam` commands | `aws sso-admin` + Console |

---

## Troubleshooting Terraform

### Error: "No instances found"

```
Error: error reading SSO Instances: empty result
```

**Causa:** IAM Identity Center no está habilitado en us-east-1.

**Solución:** Completar Fase 1.2 (habilitar IAM Identity Center en consola).

### Error: "User not found"

```
Error: reading IdentityStore User: ResourceNotFoundException
```

**Causa:** Usuario `claguirre` no existe en Identity Store.

**Solución:** Completar Fase 1.4 (crear usuario en consola o CLI).

**Verificar:**
```bash
IDENTITY_STORE_ID=$(aws sso-admin list-instances --region us-east-1 \
  --query 'Instances[0].IdentityStoreId' --output text)

aws identitystore list-users \
  --identity-store-id $IDENTITY_STORE_ID \
  --region us-east-1
```

### Error: "Policy not found"

```
Error: error reading IAM policy (edugami-dev-readonly-policy): NoSuchEntity
```

**Causa:** La política IAM no existe (módulo `readonly-users` no aplicado).

**Solución:** Asegurar que `module.readonly_users` está desplegado en el mismo ambiente.

```bash
cd environments/dev
terraform state list | grep readonly_users

# Si no existe:
terraform apply  # Esto creará el módulo readonly_users primero
```

### Warning: Cyclic Dependency

Si ves warnings sobre dependencias cíclicas:

**Solución:** El `depends_on` en `sso-users.tf` resuelve esto. Verificar que esté presente:

```hcl
module "sso_readonly" {
  # ...
  depends_on = [module.readonly_users]
}
```

---

## Operaciones Post-Despliegue

### Agregar Nuevos Usuarios

```bash
# 1. Crear usuario en IAM Identity Center
# Via consola: https://console.aws.amazon.com/singlesignon/ → Users → Add user
# Via CLI:
aws identitystore create-user \
  --identity-store-id d-abc123xyz \
  --user-name nuevo.usuario \
  --display-name "Nuevo Usuario" \
  --emails Value=nuevo@edugami.pro,Primary=true \
  --name Formatted="Nuevo Usuario",FamilyName=Usuario,GivenName=Nuevo

# 2. Editar environments/dev/sso-users.tf
# Agregar "nuevo.usuario" a la lista sso_users

# 3. Aplicar Terraform
cd environments/dev
terraform apply

# 4. Usuario recibe email y configura CLI
```

### Remover Usuarios

```bash
# 1. Quitar username de sso_users list en sso-users.tf

# 2. Aplicar Terraform
terraform apply
# Esto elimina la asignación pero NO el usuario de Identity Store

# 3. (Opcional) Desactivar usuario en Identity Center
# Console → IAM Identity Center → Users → [usuario] → Disable
```

### Auditoría de Accesos

```bash
# Ver eventos SSO en CloudTrail (últimas 24h)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithSAML \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --region us-east-1

# Ver asignaciones actuales
aws sso-admin list-account-assignments \
  --instance-arn arn:aws:sso:::instance/sso-instance/ins-abc123 \
  --account-id 123456789012 \
  --permission-set-arn arn:aws:sso:::permissionSet/ins-abc123/ps-xyz789
```

---

## Costos

| Servicio | Costo |
|----------|-------|
| AWS Organizations | **$0** |
| IAM Identity Center | **$0** |
| SSO Permission Sets | **$0** |
| Identity Store (hasta 50 usuarios) | **$0** |
| **TOTAL ADICIONAL** | **$0** |

No hay costos adicionales por implementar SSO. Es un servicio gratuito de AWS.

---

## Seguridad Adicional (Recomendaciones)

### 1. Forzar MFA para Todos los Usuarios

```
Console → IAM Identity Center → Settings → Authentication
→ Multi-factor authentication → Configure
→ Select: "Every time they sign in (always-on)"
→ Save
```

### 2. Reducir Session Duration en PROD

Editar `environments/prod/sso-users.tf`:

```hcl
module "sso_readonly" {
  # ...
  session_duration = "PT4H"  # 4 horas en vez de 8
}
```

### 3. Configurar Password Policy

```
Console → IAM Identity Center → Settings → Password policy
→ Configure: Minimum 14 characters, require symbols, expire after 90 days
```

### 4. Monitoreo de Actividad SSO

Crear alarma CloudWatch para logins fallidos:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "SSO-Failed-Logins" \
  --alarm-description "Alert on multiple SSO login failures" \
  --metric-name UserAuthenticationFailed \
  --namespace AWS/SSO \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

---

## Validación Completa (Checklist)

### Pre-Terraform
- [ ] AWS Organizations habilitado
- [ ] IAM Identity Center habilitado en us-east-1
- [ ] Usuario SSO `claguirre` creado
- [ ] SSO Instance ARN obtenido

### Post-Terraform (DEV)
- [ ] `terraform apply` exitoso
- [ ] Permission set `edugami-dev-readonly` creado
- [ ] Política `edugami-dev-readonly-policy` adjuntada
- [ ] Usuario `claguirre` asignado
- [ ] SSO Start URL disponible en outputs

### Configuración Usuario
- [ ] Email de invitación recibido
- [ ] Contraseña configurada
- [ ] MFA habilitado
- [ ] AWS CLI v2 instalado
- [ ] `aws configure sso` completado
- [ ] `aws sso login` funciona
- [ ] `aws sts get-caller-identity` muestra SSO role

### Testing Permisos
- [ ] ✅ `aws ecs describe-clusters` funciona
- [ ] ✅ `aws logs tail` funciona
- [ ] ✅ `aws rds describe-db-instances` funciona
- [ ] ❌ `aws ecs update-service` falla con AccessDenied
- [ ] ❌ `aws ssm put-parameter` falla con AccessDenied

### Post-Testing
- [ ] Usuario familiarizado con `aws sso login` workflow
- [ ] Documentación compartida con el equipo
- [ ] Plan de migración comunicado
- [ ] Fecha definida para deshabilitar IAM users

---

## Referencias

- **AWS Docs:** https://docs.aws.amazon.com/singlesignon/
- **Terraform AWS SSO:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set
- **Guía Usuario (ES):** [SSO_GUIA_USUARIO.md](./SSO_GUIA_USUARIO.md)
- **Plan Original:** `/Users/carlos/.claude/projects/-Users-carlos-Desktop-Edugami-terraform-backend/b7a45db1-8dd4-487c-8930-17f0963a505d.jsonl`

---

**Última actualización:** 2026-01-29
**Versión Terraform AWS Provider:** ~> 5.0
**Estado:** Fase 2 Completada - Listo para Fase 3 (Terraform Apply)
