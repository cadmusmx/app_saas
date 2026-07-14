# Pruebas manuales — S2: Resolver tenant + Login con MFA

> Bitácora de validación de `gaso_tenant_app` (S2). Sin DoD/CI en alcance: esta
> bitácora es la evidencia antes de pasar la card a DONE y avanzar a S3.
> Contrato de referencia: `docs/BFF_MOBILE_AUTH_CONTRACT.md` (versión FINAL del BFF).

## Modelo de flujo (login combinado)

El usuario ingresa **empresa (dominio) + usuario + contraseña** en un solo
formulario. No hay paso `resolve-tenant` previo como gate: el slug viaja como
`x-tenant-slug` y el BFF valida empresa + credenciales juntos en
`POST /api/auth-mfa/start`. **MFA (TOTP) es obligatorio**: si el usuario no lo
tiene, la app entra al flujo de configuración. La sesión se emite en
`POST /api/mobile/login` (JWT Bearer, `expiresIn` 24 h).

> `resolve-tenant` queda solo como conveniencia para una futura pantalla de
> validación/branding de empresa; no está en la ruta crítica del login.

## Entorno de prueba

| Campo | Valor |
| --- | --- |
| Build | `gaso_tenant_app` — rama: `develop` — commit: `ef5048e947a8084724ce7cf5037a6432fcb9468e` |
| Entorno | dev (`API_URL` por defecto `http://10.0.2.2:3000/api`) |
| BFF | Gaso SaaS - NextJS (`apps/main`) — rama: `develop_djaime` |
| Dispositivo/OS | Android Emulator Medium_Phone_API_35:5554 |
| Fecha / Tester | 23/06/2026 / Diego Jaime |

## Datos de prueba (tenants de dev)

| Empresa (campo "Dominio") | Estado |
| --- | --- |
| `gasohub.com` | Activo |
| `alfa.com` | Activo |
| `ericsson.gasohub.com` | Activo |

> No hay tenant **suspendido** en dev: para TC-04 suspender uno en el BFF
> (`Status` ≠ ACTIVE/TRIAL). Ojo: `resolve-tenant` cachea ~5 min, pero el login
> revalida el estado en `/api/mobile/login`. Usuario/credenciales y secret TOTP:
> completar con cuentas de dev.

## Resultados

Marca: (✓) pasa · (X) falla · (!) con observación. Adjunta captura/log en "Notas".

### Login + validación de empresa (combinado)

| ID | Caso | Pasos | Resultado esperado | Res. | Notas |
| --- | --- | --- | --- | --- | --- |
| TC-01 | Login con MFA ya configurado (happy path) | Empresa válida + credenciales válidas → ingresar código TOTP vigente | `auth-mfa/start` pide MFA; tras el código, `/mobile/login` devuelve JWT y entra a Home; requests posteriores llevan `x-tenant-slug` + `Authorization: Bearer` | ✓ | |
| TC-02 | Empresa inexistente | Empresa `noexiste.com` + credenciales → entrar | Bloqueo claro (HTTP 404 vía middleware); no continúa | ✓ | |
| TC-03 | Credenciales inválidas (empresa válida) | Empresa válida + usuario/contraseña incorrectos | Mensaje de credenciales inválidas (HTTP 401 `INVALID_CREDENTIALS`); no crea sesión | ✓ | |
| TC-04 | Empresa suspendida | Dominio de un tenant suspendido + credenciales válidas | Bloqueo (HTTP 403 `TENANT_SUSPENDED`); estado "blocked", no continúa | ✓ | |
| TC-05 | Campos incompletos | Dejar empresa/usuario/contraseña vacío | Mensaje "Completa todos los campos"; no se llama al BFF | ✓ | |

### MFA (TOTP — `@otplib`, sin Cognito ni SMS)

| ID | Caso | Pasos | Resultado esperado | Res. | Notas |
| --- | --- | --- | --- | --- | --- |
| TC-06 | Configuración de MFA por primera vez | Usuario sin TOTP → la app muestra QR + clave manual → registrar en app Auth 2FA → ingresar primer código | `setup/start` da `otpauthUrl`/`manualKey`; `setup/verify` confirma; continúa al reto y crea sesión | ✓ | |
| TC-07 | Código TOTP inválido | En el reto, ingresar un código incorrecto | HTTP 401 `MFA_INVALID`; muestra error, limpia el campo y permite reintentar | ✓ | |
| TC-08 | Código TOTP expirado / reto vencido | Esperar >30 s con un código viejo, o >5 min desde el reto | HTTP 401 `MFA_EXPIRED`; la app avisa y regresa al login para reiniciar el reto | ✓ | |

### Deep link

| ID | Caso | Pasos | Resultado esperado | Res. | Notas |
| --- | --- | --- | --- | --- | --- |
| TC-09 | Pre-llena empresa (sin sesión) | Cerrar app → abrir `gasosaas://tenant/gasohub.com` | Abre el login con empresa pre-llenada en `gasohub.com`; no salta el flujo de credenciales | ✓ | |
| TC-10 | Con sesión activa de otro tenant | Con sesión en `gasohub.com`, abrir `gasosaas://tenant/alfa.com` | Diálogo "Cambiar empresa"; al aceptar cierra sesión y va al login pre-llenado con `alfa.com` | X | Solo abre la app en Home |
| TC-11 | Deep link en iOS | Repetir TC-09 en iOS | Igual que Android (requiere `CFBundleURLTypes` en `Info.plist`) | | |

### Sesión

| ID | Caso | Pasos | Resultado esperado | Res. | Notas |
| --- | --- | --- | --- | --- | --- |
| TC-12 | Persistencia de sesión | Iniciar sesión → cerrar y reabrir la app | La sesión sobrevive mientras el JWT siga vigente (24 h); no re-pide login | ✓ | |
| TC-13 | Persistencia del tenant | Sin sesión, reabrir la app | El campo empresa se pre-llena con el último dominio usado (editable) | ✓ | |
| TC-14 | Sesión expirada (local) | Forzar expiry vencido en secure storage → reabrir | La app limpia la sesión y redirige a login | ✓ | |
| TC-15 | 401 del BFF en petición autenticada | Con sesión, provocar un 401 en una llamada `send()` (token revocado/expirado lado server) | `onUnauthorized` invalida la sesión y redirige a login (camino que reutiliza S3 con `/api/me`) | ✓ | |

## Observaciones / bugs encontrados

- No se realizaron pruebas con IOS, TC-15 se hizo forzando la expiración del token (falta probar con otros endpoints)

## Veredicto

- [✓] Casos críticos (TC-01, 02, 03, 04, 06, 07, 12, 15) en (✓) → S2 listo para DONE.
