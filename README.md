# gaso_tenant_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Estructura del proyecto

```
├── app/                          # Capa de aplicación: shell, navegación y composición global
│   ├── router/
│   │   └── routes.dart           # Constantes tipadas de rutas (AppRoutes) y configuración del Navigator
│   ├── widgets/                  # Widgets del shell de la app (no específicos de un feature)
│   │   ├── appbar_header.dart    # AppBar personalizado reutilizado en pantallas principales
│   │   ├── drawer_lateral.dart   # Menú lateral de navegación
│   │   └── ...
│   └── app.dart                  # Widget raíz: MaterialApp, tema, locale y wiring inicial
│
├── core/                         # Infraestructura transversal compartida por todos los features
│   ├── access/                   # Control de acceso y permisos de usuario
│   ├── config/                   # Configuración de entornos, endpoints, keys y flags
│   ├── constants/                # Constantes globales (colores, tamaños, claves)
│   ├── enums/                    # Enumeraciones compartidas
│   ├── extensions/               # Extension methods sobre tipos de Dart/Flutter
│   ├── helpers/                  # Funciones utilitarias de propósito general
│   ├── logging/                  # Configuración y utilidades de logging
│   ├── services/                 # Servicios compartidos (FCM, conectividad, etc.)
│   ├── storage/                  # Abstracciones de almacenamiento local (prefs, secure storage)
│   ├── validators/               # Validadores de input para formularios
│   ├── widgets/                  # Widgets genéricos reutilizables entre features
│   └── ...
│
├── features/                     # Módulos de funcionalidad (feature-first)
│   ├── auth/                     # Autenticación: login, sesión, recuperación
│   │   ├── data/                 # Fuentes de datos, modelos, mapeos y caché del feature
│   │   ├── domain/               # Entidades y lógica de negocio propia del feature
│   │   └── presentation/         # Pantallas, controladores de UI y widgets del feature
│   ├── home/                     # Pantalla principal / dashboard tras el login
│   └── ...
```

### Notas de la estructura

- La regla implícita de features/<name>/{data,domain,presentation} es que nada en core/ depende de un feature, y los features evitan depender entre sí; cuando lo necesitan, el dato/lógica compartido se mueve al feature receptor.
- app/ también podría describirse como "todo lo que necesita conocer toda la app para arrancar", lo que la diferencia de core/ (piezas reutilizables sin estado global).

## Variables de entorno

Crear el archivo .env basado en .env.example, después genera el env.g.dart mediante el comando:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Otros Recursos

Iconos: [Freepik](https://www.freepik.com/author/freepik/icons/basic-straight-lineal_1)