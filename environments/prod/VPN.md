# VPN Edugami — Guía de uso

El equipo se conecta a la base de datos PROD vía **WireGuard VPN**.
Un solo EC2 (bastion) actúa como servidor VPN y como túnel SSH para n8n.

---

## Cómo funciona

```
Tu Mac ──── WireGuard (UDP 51820) ────► EC2 Bastion (23.21.26.99) ────► RDS (privada)
n8n    ──── SSH tunnel (TCP 22)   ────► EC2 Bastion (23.21.26.99) ────► RDS (privada)
```

- La RDS nunca está expuesta a internet
- Cada persona del equipo tiene su propio keypair WireGuard
- El tráfico personal NO pasa por la VPN — solo el tráfico hacia la VPC (`10.0.0.0/16`)

---

## Agregar un nuevo usuario

### Paso 1 — Generar su keypair

```bash
# Desde la raíz del repo
./scripts/generate-vpn-keys.sh peer <nombre>

# Ejemplo
./scripts/generate-vpn-keys.sh peer maria
```

El script imprime:
- **Public key** → va en `terraform.tfvars`
- **Private key** → va en el archivo `.conf` que le mandas a la persona

### Paso 2 — Agregar al terraform.tfvars

Abrir `environments/prod/terraform.tfvars` y agregar en `vpn_peers`:

```hcl
vpn_peers = {
  "carlos" = {
    public_key = "..."
    vpn_ip     = "10.8.0.2"
  }
  "maria" = {                                    # ← nuevo
    public_key = "PUBLIC_KEY_DEL_PASO_1"
    vpn_ip     = "10.8.0.7"                      # siguiente IP disponible
  }
}
```

**IPs asignadas hasta ahora:**
| Nombre       | IP VPN     |
|--------------|------------|
| Servidor     | 10.8.0.1   |
| carlos       | 10.8.0.2   |
| directiva    | 10.8.0.3   |
| vicky        | 10.8.0.4   |
| juan_andres  | 10.8.0.5   |
| rosario      | 10.8.0.6   |
| *próximo*    | 10.8.0.7   |

### Paso 3 — Aplicar Terraform

```bash
cd environments/prod
terraform apply
```

Terraform reconfigura el EC2 con el nuevo peer. No hay downtime — el EC2 no se reinicia.

> **Nota:** el nuevo peer solo queda activo después del siguiente reinicio del EC2
> (Stop → Start en consola AWS). Si el EC2 ya tiene WireGuard corriendo, también
> puedes actualizar la config a mano sin reiniciar:
> ```bash
> ssh -i <tu-key> ec2-user@23.21.26.99
> sudo wg addconf wg0 <(echo "[Peer]
> PublicKey = <public_key>
> AllowedIPs = 10.8.0.7/32")
> ```

### Paso 4 — Crear el archivo .conf para la persona

Crear `environments/prod/vpn-configs/<nombre>.conf`:

```ini
[Interface]
Address = 10.8.0.7/24
PrivateKey = PRIVATE_KEY_DEL_PASO_1
DNS = 8.8.8.8

[Peer]
PublicKey = JJl8BLgyLvrDJJTL2BGbrN0WU9r+EFvcl33SfUm6L2o=
Endpoint = 23.21.26.99:51820
AllowedIPs = 10.0.0.0/16
PersistentKeepalive = 25
```

Mandarle el `.conf` por un canal seguro (no email, preferir Signal o 1Password).

### Paso 5 — Instrucciones para la persona

1. Descargar **WireGuard** (Mac: App Store / Windows: wireguard.com)
2. Abrir WireGuard → **Import tunnel(s) from file** → seleccionar su `.conf`
3. Click **Activate**
4. Conectarse a DBeaver con el endpoint de la RDS

---

## Revocar acceso a un usuario

```hcl
# Eliminar su entrada en terraform.tfvars
vpn_peers = {
  "carlos" = { ... }
  # "maria" eliminada  ← acceso revocado inmediatamente al hacer apply
}
```

```bash
terraform apply
```

---

## Conectarse a DBeaver

Una vez conectado a la VPN:

| Campo    | Valor                                      |
|----------|--------------------------------------------|
| Host     | (endpoint RDS — ver `terraform output rds_endpoint`) |
| Puerto   | 5432                                       |
| Database | edugami_platform                           |
| Usuario  | edugami_admin                              |
| Password | (ver SSM Parameter Store en consola AWS)   |

---

## Datos del servidor VPN

| Dato              | Valor                                              |
|-------------------|----------------------------------------------------|
| IP pública (EIP)  | 23.21.26.99                                        |
| Puerto WireGuard  | UDP 51820                                          |
| VPN CIDR          | 10.8.0.0/24                                        |
| Server public key | JJl8BLgyLvrDJJTL2BGbrN0WU9r+EFvcl33SfUm6L2o=     |
| Server private key| SSM: `/edugami/prod/vpn/server_private_key`        |
