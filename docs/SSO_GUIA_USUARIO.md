# Guía de Usuario - AWS SSO (IAM Identity Center)

**Acceso Read-Only a Infraestructura de Edugami**

---

## ¿Qué es AWS SSO?

AWS SSO (también llamado IAM Identity Center) es un sistema de autenticación que te permite acceder a AWS usando credenciales temporales que expiran automáticamente cada 8 horas. Esto es más seguro que las claves de acceso permanentes.

**Ventajas:**
- ✅ Credenciales temporales (auto-expiran cada 8 horas)
- ✅ No necesitas rotar claves manualmente
- ✅ Login fácil con `aws sso login` (abre browser)
- ✅ Mismo método para acceder a múltiples ambientes (DEV, PROD)
- ✅ Más seguro (si tus credenciales se filtran, expiran pronto)

---

## Configuración Inicial (Solo Una Vez)

### Paso 1: Revisa tu Email

Busca un email de AWS con asunto: **"Invitation to join AWS Single Sign-On"**

1. Abre el email
2. Click en el link de invitación
3. Configura tu contraseña (sigue las reglas de complejidad)
4. **Configura MFA** (autenticación de dos factores) - RECOMENDADO
5. Anota el **SSO Start URL** (ej: `https://d-abc123xyz.awsapps.com/start`)

### Paso 2: Instala/Actualiza AWS CLI v2

**IMPORTANTE**: AWS SSO solo funciona con AWS CLI versión 2.x

#### macOS
```bash
# Verificar versión actual
aws --version

# Si es v1, desinstalar e instalar v2
brew install awscli
```

#### Linux
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### Windows
Descarga el instalador: https://aws.amazon.com/cli/

**Verificar instalación:**
```bash
aws --version
# Debe mostrar: aws-cli/2.x.x ...
```

### Paso 3: Configurar Perfil SSO

```bash
aws configure sso
```

Te hará las siguientes preguntas:

```
SSO session name (Recommended): edugami
SSO start URL [None]: https://d-abc123xyz.awsapps.com/start
SSO region [None]: us-east-1
SSO registration scopes [sso:account:access]: [presiona Enter]
```

Luego se abrirá tu browser para autorizar el acceso:
1. Login con tus credenciales SSO
2. Click "Allow access"
3. Cierra el browser y vuelve a la terminal

Continúa respondiendo:

```
There is 1 AWS account available to you.
Using the account ID 123456789012

There are 2 roles available to you.
> edugami-dev-readonly   [SELECCIONA ESTA]
  edugami-prod-readonly

Using the role name "edugami-dev-readonly"

CLI default client Region [None]: us-east-1
CLI default output format [None]: json
CLI profile name [edugami-dev-readonly]: edugami-dev
```

### Paso 4: Verificar Configuración

Revisa tu archivo `~/.aws/config`:

```bash
cat ~/.aws/config
```

Debe contener algo como:

```ini
[profile edugami-dev]
sso_session = edugami
sso_account_id = 123456789012
sso_role_name = edugami-dev-readonly
region = us-east-1
output = json

[sso-session edugami]
sso_start_url = https://d-abc123xyz.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access
```

---

## Uso Diario

### Login (Cada Mañana o Cuando Expire la Sesión)

```bash
# Configurar el perfil a usar
export AWS_PROFILE=edugami-dev

# Login (abre browser automáticamente)
aws sso login

# Si el browser no abre automáticamente
aws sso login --no-browser
# (Copia y pega la URL en tu browser manualmente)
```

**Importante:** Las credenciales expiran cada 8 horas. Cuando expiren, simplemente vuelve a ejecutar `aws sso login`.

### Usar AWS CLI Normalmente

Una vez logueado, usa AWS CLI como siempre:

```bash
# Ver clusters de ECS
aws ecs list-clusters

# Ver servicios
aws ecs describe-services --cluster edugami-dev-cluster --services edugami-dev-web

# Ver logs en tiempo real
aws logs tail /ecs/edugami-dev-web --follow

# Ver últimas 100 líneas de logs
aws logs tail /ecs/edugami-dev-web --since 1h

# Ver bases de datos
aws rds describe-db-instances

# Ver parámetros de configuración
aws ssm get-parameter --name /edugami/dev/DATABASE_URL
```

### Logout (Opcional)

```bash
aws sso logout
```

---

## Acceso a Múltiples Ambientes (DEV y PROD)

Si tienes acceso a múltiples ambientes, configura un perfil para cada uno:

### Configurar Perfil de PROD

```bash
aws configure sso
# Usa el mismo SSO Start URL
# Selecciona "edugami-prod-readonly" cuando te pregunte
# Nombre del perfil: edugami-prod
```

### Cambiar Entre Ambientes

```bash
# Trabajar en DEV
export AWS_PROFILE=edugami-dev
aws sso login
aws ecs list-clusters

# Cambiar a PROD
export AWS_PROFILE=edugami-prod
aws sso login
aws ecs list-clusters
```

**Tip:** Agrega esto a tu `~/.bashrc` o `~/.zshrc` para tener aliases:

```bash
alias aws-dev='export AWS_PROFILE=edugami-dev && aws sso login'
alias aws-prod='export AWS_PROFILE=edugami-prod && aws sso login'
```

Luego solo ejecuta:
```bash
aws-dev   # Login a DEV
aws-prod  # Login a PROD
```

---

## Acceso a Consola Web

También puedes acceder a la consola de AWS usando SSO:

1. Abre tu **SSO Start URL** en el browser: `https://d-abc123xyz.awsapps.com/start`
2. Login con tus credenciales
3. Click en la cuenta AWS que quieres acceder
4. Click en **"Management console"**
5. Navega a los servicios: ECS, CloudWatch, RDS, etc.

---

## Permisos de Solo Lectura

Tienes permisos para **VER** pero **NO MODIFICAR** la infraestructura:

### ✅ Puedes Hacer (Lectura)

- Ver servicios y tasks de ECS
- Leer logs de CloudWatch
- Ver métricas y alarmas
- Ver estado de bases de datos RDS
- Ver configuración de Redis (ElastiCache)
- Ver Load Balancers
- Leer parámetros de SSM Parameter Store
- Ver imágenes Docker en ECR

### ❌ NO Puedes Hacer (Escritura)

- Modificar servicios de ECS
- Crear o eliminar recursos
- Cambiar configuraciones
- Modificar bases de datos
- Crear o modificar parámetros
- Escalar servicios

**Si intentas una acción no permitida**, verás un error como:
```
An error occurred (AccessDenied) when calling the UpdateService operation:
User is not authorized to perform: ecs:UpdateService
```

---

## Troubleshooting (Solución de Problemas)

### Error: "Session token expired"

**Solución:** Tus credenciales expiraron (pasan 8 horas). Vuelve a hacer login:

```bash
aws sso login
```

### Error: "SSO session associated with this profile has expired"

**Solución:** Mismo caso, vuelve a hacer login:

```bash
aws sso login --profile edugami-dev
```

### Error: "Unable to open browser"

**Causa:** Estás en un servidor sin interfaz gráfica.

**Solución:** Usa modo manual:

```bash
aws sso login --no-browser
# Copia la URL que aparece
# Pégala en tu browser local
# Autoriza el acceso
```

### Error: "The config profile (edugami-dev) could not be found"

**Causa:** El perfil no está configurado.

**Solución:** Vuelve a ejecutar `aws configure sso` y sigue los pasos.

### Browser no abre automáticamente en macOS

**Solución:** Verifica permisos:

```bash
# Intenta abrir manualmente
open https://device.sso.us-east-1.amazonaws.com/

# Si no funciona, usa --no-browser
aws sso login --no-browser
```

### Error: "InvalidClientTokenId" después de login

**Causa:** Las credenciales cacheadas están corruptas.

**Solución:** Borra el cache y vuelve a hacer login:

```bash
rm -rf ~/.aws/sso/cache/
rm -rf ~/.aws/cli/cache/
aws sso login
```

---

## Comandos Útiles

### Ver Info de tu Identidad Actual

```bash
aws sts get-caller-identity
```

Output esperado:
```json
{
    "UserId": "AROA...:claguirre",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/edugami-dev-readonly/claguirre"
}
```

### Ver Cuando Expiran tus Credenciales

```bash
aws sts get-session-token
# O revisa: ~/.aws/cli/cache/
```

### Listar Todos tus Perfiles Configurados

```bash
aws configure list-profiles
```

### Ver Configuración de un Perfil

```bash
aws configure list --profile edugami-dev
```

---

## Mejores Prácticas

1. **Haz login al inicio del día**: Evita interrupciones por credenciales expiradas
2. **No compartas credenciales**: Cada persona debe tener su propio usuario SSO
3. **Usa perfiles específicos**: No mezcles perfiles de DEV y PROD
4. **Configura MFA**: Activa autenticación de dos factores para mayor seguridad
5. **Cierra sesión en computadoras compartidas**: Usa `aws sso logout`
6. **Reporta problemas de acceso**: Si no puedes acceder a algo que necesitas, contacta al equipo

---

## Soporte

### Necesito Acceso a Otro Ambiente

Contacta al administrador de infraestructura. Ellos agregarán tu usuario a la lista de `sso_users` en Terraform y aplicarán los cambios.

### Olvidé mi Contraseña SSO

1. Ve al SSO Start URL
2. Click en "Forgot password?"
3. Sigue las instrucciones enviadas a tu email

### Necesito Permisos Adicionales

Los permisos read-only son por diseño. Si necesitas modificar infraestructura:
- Solicita los cambios al equipo de DevOps
- O solicita permisos elevados temporalmente (debe ser justificado)

---

## Comparación: IAM Users vs AWS SSO

| Aspecto | IAM User (Antes) | AWS SSO (Ahora) |
|---------|------------------|-----------------|
| **Credenciales** | Permanentes (access keys) | Temporales (8 horas) |
| **Login** | Una vez (keys en `~/.aws/credentials`) | Cada 8 horas (`aws sso login`) |
| **Seguridad** | Si keys se filtran, son válidas hasta rotarlas manualmente | Keys auto-expiran, riesgo minimizado |
| **Setup** | `aws configure` | `aws configure sso` (más pasos, pero más seguro) |
| **Multi-ambiente** | Un par de keys por ambiente | Un solo login, múltiples perfiles |

---

## Cheat Sheet Rápido

```bash
# Login
export AWS_PROFILE=edugami-dev
aws sso login

# Ver clusters
aws ecs list-clusters

# Ver servicios
aws ecs describe-services --cluster edugami-dev-cluster --services edugami-dev-web

# Ver logs en vivo
aws logs tail /ecs/edugami-dev-web --follow

# Ver logs de última hora
aws logs tail /ecs/edugami-dev-web --since 1h

# Ver bases de datos
aws rds describe-db-instances

# Ver parámetro
aws ssm get-parameter --name /edugami/dev/REDIS_URL

# Verificar identidad
aws sts get-caller-identity

# Logout
aws sso logout
```

---

**¿Preguntas?** Contacta al equipo de infraestructura o DevOps.

**Última actualización:** 2026-01-29
