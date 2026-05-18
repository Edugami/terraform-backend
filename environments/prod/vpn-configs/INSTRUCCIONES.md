# Cómo conectarse a la base de datos Edugami

Estas instrucciones te permiten conectarte a la base de datos de producción desde tu computador.
Necesitas hacerlo **una sola vez** — después solo es activar la VPN y abrir DBeaver.

---

## Lo que necesitas instalar

1. **WireGuard** — la VPN
   - Mac: [App Store → WireGuard](https://apps.apple.com/app/wireguard/id1451685025)
   - Windows: [wireguard.com/install](https://www.wireguard.com/install/)

2. **DBeaver** — para ver la base de datos
   - [dbeaver.io/download](https://dbeaver.io/download/) → Community Edition (gratis)

---

## Paso 1 — Configurar la VPN

1. Abre **WireGuard**
2. Click en **Import tunnel(s) from file**
3. Selecciona el archivo `.conf` que te mandó Carlos (ej: `vicky.conf`)
4. Click **Activate**

Cuando el punto al lado del túnel esté **verde**, estás conectada/o. ✅

> Cada vez que quieras conectarte a la base de datos, debes activar la VPN primero.
> Puedes desactivarla cuando termines — no afecta tu conexión a internet normal.

---

## Paso 2 — Configurar DBeaver

1. Abre **DBeaver**
2. Click en **New Database Connection** (ícono del enchufe con el +)
3. Selecciona **PostgreSQL** → Next
4. Completa los datos:

| Campo    | Valor |
|----------|-------|
| Host     | `edugami-prod-db.cmnqiao2eqqa.us-east-1.rds.amazonaws.com` |
| Port     | `5432` |
| Database | `edugami_platform` |
| Username | `edugami_readonly` |
| Password | *(te lo manda Carlos por separado)* |

5. Click **Test Connection** — debe decir "Connected" ✅
6. Click **Finish**

---

## Uso diario

Cada vez que quieras revisar la base de datos:

```
1. Abre WireGuard → Activate
2. Abre DBeaver → conectar
3. Al terminar → Deactivate en WireGuard
```

---

## Problemas frecuentes

**"Connection refused" o timeout en DBeaver**
→ Verifica que WireGuard esté activado (punto verde)

**WireGuard no conecta**
→ Asegúrate de haber importado el archivo `.conf` correcto (cada persona tiene el suyo)

**No veo tablas en DBeaver**
→ Expande en el panel izquierdo: `edugami_platform` → `Schemas` → `public` → `Tables`

---

*¿Problemas? Escríbele a Carlos.*
