# BFF ↔ Flutter — Contrato de Autenticación Móvil (FINAL)

> **Estado:** verificado end-to-end contra el código real del BFF. Todos los endpoints, shapes y códigos de abajo fueron probados con `curl` durante la implementación (pasos 1–5).
> **Cliente:** `gaso_tenant_app` (Flutter) → BFF Next.js (`apps/main`).
> **Origen:** la app SIEMPRE envía `x-origin-id: 3` (APP) y `x-tenant-slug: <dominio>` en las rutas de auth.

---

## 0. Modelo de resolución de tenant (lo que la app debe saber)

El BFF resuelve el tenant de forma distinta según el origen:

- **Web:** por subdominio del host (el middleware lo extrae y lo inyecta).
- **Móvil (`x-origin-id: 3`):** por el header **`x-tenant-slug`**. Una rama dedicada del middleware lo resuelve contra `Security.Tenants`, valida que exista y esté activo, e inyecta `x-tenant-id` para las rutas. Responde **JSON** (no redirects HTML).

Por eso la app NO necesita un paso `resolve-tenant` previo como gate de login: puede mandar slug + usuario + contraseña y el BFF valida todo junto. El `resolve-tenant` (sección 3) sirve solo para la pantalla de selección/validación de empresa.

**Base URL:** la app pega a un host plano (apex/`api.`) con `x-tenant-slug`; no necesita subdominio por tenant.

---

## 1. Catálogo de orígenes (auditoría)

| id | nombre | quién |
|----|--------|-------|
| 1  | DB  | procesos internos |
| 2  | WEB | navegador |
| 3  | APP | **móvil — usar este** |

Toda request de auth de la app envía `x-origin-id: 3`. Los eventos de login/MFA quedan auditados como APP.

---

## 2. Headers estándar de la app

En todas las rutas de auth y en `/api/me`:

```
x-origin-id: 3
x-tenant-slug: <dominio del tenant, ej. gasohub.com>
content-type: application/json   (en POST con body)
```

En rutas protegidas tras login:

```
authorization: Bearer <accessToken>
```

---

## 3. Validación de empresa (pantalla de selección)

### `GET /api/internal/resolve-tenant?domain=<slug>`  — público

- **Query param:** `domain` (literal; NO `slug`). Falta → `400 { "error": "Missing domain" }`.
- **Respuesta (siempre `200`):**
  ```json
  { "tenant": { "TenantID": "GUID", "CompanyName": "string|null", "isActive": true, "Dominio": "string|null" } }
  ```
  o `{ "tenant": null }` si no existe (**también `200`**, no `404`).
- `isActive` es **booleano**, derivado de `Status` en la DB (`ACTIVE`/`TRIAL` → `true`). La columna física es `Status`; la app nunca la ve.
- **No filtra** suspendidos: un tenant inactivo regresa con `isActive: false`. La app debe checar el bool y bloquear/mostrar mensaje.
- Cacheado ~300 s. Tras suspender un tenant puede quedar stale hasta 5 min.

> La app persiste el `Dominio` (lo usará como `x-tenant-slug`) y el `TenantID`.

---

## 4. Flujo de login (3 pasos)

Todas usan headers de la sección 2. Campo de usuario en el body: **`username`**.

### 4.1 `POST /api/auth-mfa/start`
Inicia el reto MFA tras validar credenciales.

- **Body:** `{ "username": string, "password": string }`
- **Respuestas:**
  - `200` reto creado (el usuario ya tiene TOTP):
    ```json
    { "ok": true, "requiresMfa": true, "requiresMfaSetup": false, "challengeId": "uuid", "factorType": "TOTP" }
    ```
  - `200` setup requerido (el usuario no tiene TOTP):
    ```json
    { "ok": true, "requiresMfa": false, "requiresMfaSetup": true, "reason": "MFA_SETUP_REQUIRED", "factorType": "TOTP", "message": ["MFA setup is required for this user"] }
    ```
  - `400` `{ "ok": false, "message": ["User and password are required"] }`
  - `401` `{ "ok": false, "message": ["User or Password is invalid"] }`
- **Nota:** `requiresMfa` y `requiresMfaSetup` vienen **ambos** siempre. La app decide por `requiresMfaSetup`: si `true` → flujo 4.2/4.3; si `false` → guarda `challengeId` y va a 4.4.

### 4.2 `POST /api/auth-mfa/setup/start`  (solo si requiere setup)
- **Body:** `{ "username": string, "password": string }`
- **Respuesta `200`:**
  ```json
  {
    "ok": true, "requiresMfaSetup": true, "setupId": "GUID",
    "factorType": "TOTP", "provider": "GoogleAuthenticator",
    "issuer": "Gaso-SaaS", "accountName": "email|username",
    "otpauthUrl": "otpauth://totp/…", "manualKey": "BASE32SECRET"
  }
  ```
  - `200` ya configurado: `{ "ok": true, "alreadyConfigured": true, "requiresMfaSetup": false, "message": ["MFA is already configured for this user"] }`
- La app muestra `otpauthUrl` como QR y/o `manualKey` para entrada manual.

### 4.3 `POST /api/auth-mfa/setup/verify`  (confirma el setup)
- **Body:** `{ "username": string, "password": string, "setupId": string, "mfaCode": string }`
- **Respuestas:**
  - `200` `{ "ok": true, "verified": true, "requiresMfaSetup": false, "message": ["MFA setup verified successfully"] }`
  - `400` `{ "ok": false, "message": ["User, password, setupId and MFA code are required"] }`
  - `401` `{ "ok": false, "message": ["User or Password is invalid"] }` (credenciales) / `["Invalid MFA setup code"]` (código)
  - `404` `{ "ok": false, "message": ["MFA setup factor was not found or is already verified"] }`
- Tras verificar, la app vuelve a 4.1 para obtener un `challengeId` y luego a 4.4.

### 4.4 `POST /api/mobile/login`  ← **endpoint móvil dedicado**
Valida tenant + credenciales + MFA y emite el JWT.

- **Body:** `{ "username": string, "password": string, "challengeId": string, "mfaCode": string }`
- **Respuesta éxito `200`:**
  ```json
  {
    "id": 520,
    "name": "Diego Jaime Jiménez",
    "email": "diego.jimenez@gasocom.com",
    "admin": true,
    "tenantId": "0b6e58ba-df85-4d9e-9eac-d6f4d2b783cf",
    "tenantSlug": "gasohub.com",
    "tenantName": "Tenant GASO",
    "accessToken": "<JWT>",
    "tokenType": "Bearer",
    "expiresIn": 86400
  }
  ```
  - `accessToken`: JWT **HS256**. Claims: `sub` (= `id` del usuario, string), `tenantId`, `name`, `email`, `admin`, `iat`, `exp`.
  - `expiresIn`: **segundos** (86400 = 24 h).
- **Errores (envelope normalizado `{ ok:false, code, message:[] }`):**

| Situación | HTTP | `code` |
|---|---|---|
| Tenant suspendido | `403` | `TENANT_SUSPENDED` |
| Credenciales inválidas | `401` | `INVALID_CREDENTIALS` |
| Falta MFA | `401` | `MFA_REQUIRED` |
| Challenge inválido / no encontrado / código TOTP inválido / factor no configurado / max intentos | `401` | `MFA_INVALID` |
| Challenge expirado | `401` | `MFA_EXPIRED` |
| Error de servidor | `500` | `SERVER_ERROR` |

> El check de tenant suspendido ocurre **antes** de validar credenciales o emitir JWT (defensa en profundidad; el middleware ya bloquea, pero el endpoint revalida).

---

## 5. Rutas protegidas (tras login)

### `GET /api/me`  — auth dual (cookie web **o** Bearer móvil)
- **Headers:** sección 2 + `authorization: Bearer <accessToken>`.
- **Validación:** el `tenantId` del claim del JWT debe coincidir con el tenant resuelto desde `x-tenant-slug`. Si no, `403` (un JWT no se puede reusar contra otro tenant). Verificado.
- **Respuesta `200`:**
  ```json
  {
    "user": { "id", "name", "email", "admin", "area", "cityBase", "position", "region", "company" },
    "tenant": { "id", "slug", "name", "isActive" },
    "profile": { "id", "name" },
    "permissions": [ { "moduleId", "moduleName", "subModules": [ { "id", "name" } ] } ],
    "settings": { "branding": {...}, "modules": {...}, "limits": {...} }
  }
  ```
- **Errores:** `401 { "message": "No autenticado" }` (sin/mal token), `403 { "message": "Sesión de tenant no válida" }` (cross-tenant), `404`/`500` con `{ "message": string }`.

> **Forma de error legacy:** `/api/me` devuelve `{ "message": string }` (string, no array). La app debe tolerar tanto `{ message: string }` como `{ message: [...] }` y `{ ok:false, code, message:[] }`. La normalización completa de `/api/me` es trabajo posterior coordinado (no se cambió para no romper el web).

---

## 6. Resumen de códigos para el parser de la app

| HTTP | Significado | Forma del cuerpo |
|---|---|---|
| `200` | OK | shape del endpoint |
| `400` | Falta dato / slug ausente | `{ ok:false, message:[] }` o `{ error: string }` (solo resolve-tenant) |
| `401` | Credenciales / MFA / sin sesión | `{ ok:false, code?, message:[] }` o `{ message: string }` (`/api/me`) |
| `403` | Tenant suspendido / cross-tenant | `{ ok:false, code, message:[] }` o `{ message: string }` (`/api/me`) |
| `404` | Empresa no existe (login móvil vía middleware) / factor MFA no encontrado | `{ ok:false, code?, message:[] }` |
| `500` | Error de servidor | `{ ok:false, code, message:[] }` o `{ message: string }` |
| `502` | Falló la resolución de tenant (infra) → reintentar | `{ ok:false, code:"TENANT_LOOKUP_FAILED", message:[] }` |

El parser de Flutter debe extraer el mensaje de: `message` (array → `join`), `message` (string), o `error` (string), en ese orden de tolerancia.

---

## 7. Secuencia completa (happy path móvil)

```
1. (opcional) GET /api/internal/resolve-tenant?domain=<slug>   → validar empresa
2. POST /api/auth-mfa/start            {username,password}      → challengeId  (o requiresMfaSetup)
   2a. si setup: POST /api/auth-mfa/setup/start  → otpauthUrl/manualKey
   2b.           POST /api/auth-mfa/setup/verify → verified; volver a paso 2
3. POST /api/mobile/login              {username,password,challengeId,mfaCode}
                                       → { ...user, accessToken, expiresIn }
4. Guardar accessToken (secure storage). Usarlo como Bearer.
5. GET /api/me  + Bearer               → perfil, permisos, settings
```

---

## 8. Notas de implementación (riesgos conocidos, lado BFF)

- **MFA = TOTP local (`@otplib`). No hay Cognito ni SMS.** El código TOTP depende del reloj; vale ~30 s. Si la app tarda entre leer el código y enviar `/api/mobile/login`, puede expirar → `MFA_INVALID`. (Verificado en pruebas: un código fuera de ventana da `MFA_INVALID` aunque todo lo demás sea correcto.)
- **`challengeId` en memoria del proceso (5 min).** No sobrevive reinicios del BFF ni múltiples instancias. Bajo escalado horizontal el reto creado en una instancia puede no encontrarse en otra. Pendiente de mover a store compartido (no bloquea S2, pero la app debe manejar `MFA_INVALID`/`MFA_EXPIRED` reiniciando desde el paso 2).
- **Refresh de token:** fuera de alcance S2. El `accessToken` dura 24 h; al expirar, re-login completo. Si se agrega refresh después, será aditivo.
- **`isActive` ↔ `Status`:** la respuesta expone `isActive: boolean` derivado de `Status` (`ACTIVE`/`TRIAL` = activo). Si el producto agrega estados, el criterio se ajusta en el BFF/DB; la app no cambia.

---

## 9. Cambios realizados en el BFF (referencia, ya implementados y verificados)

1. **Util JWT compartido** (`signMobileToken`/`verifyMobileToken`, `jose` HS256, secreto `MOBILE_JWT_SECRET` independiente de `NEXTAUTH_SECRET`). Roundtrip verificado.
2. **`resolveSession(req)`** — helper de validación dual (cookie NextAuth → fallback Bearer), en `packages/shared`.
3. **Middleware `apps/main` — rama `x-origin-id: 3`** — resuelve tenant desde `x-tenant-slug`, responde JSON `400/404/403/502`, inyecta `x-tenant-id`. Aditiva: no toca el flujo web.
4. **`POST /api/mobile/login`** — credenciales + MFA + check de tenant suspendido (403) + emisión de JWT + auditoría con origen APP.
5. **`GET /api/me`** — auth dual vía `resolveSession`; check cross-tenant (claim vs `x-tenant-id`) → 403.

### Pendientes coordinados (no bloquean la app)
- Normalizar envelope de error de `/api/me` a `{ ok, code, message:[] }`.
