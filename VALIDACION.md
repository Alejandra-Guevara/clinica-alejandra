# Validación local — 18 de noviembre de 2026, Colombia

## Resultado

La aplicación React y Express se ejecutó en un solo proceso y puerto. Las comprobaciones se realizaron antes de publicar el repositorio unificado.

| Comprobación | Resultado |
| --- | --- |
| Instalación con los package-lock existentes | Correcta |
| Compilación de React con Vite | Correcta |
| Lint de frontend y backend | Correcto |
| Pruebas backend | 14 aprobadas; integración optativa ejecutada por separado |
| Pruebas unitarias frontend | 5 aprobadas |
| Integración HTTP/MySQL | 1 prueba completa aprobada |
| Pruebas Playwright de interfaz | 8 aprobadas |
| Verificador del sistema completo con Chromium real | 6 comprobaciones aprobadas |
| Sintaxis YAML de OpenShift y script Bash | Correcta |

## Funciones comprobadas con MySQL aislado

- Login, sesión y CSRF mediante la misma URL de la página.
- Crear y editar pacientes desde React y comprobar su persistencia en MySQL.
- Buscar pacientes y abrir una ficha con únicamente sus consultas.
- Roles, acceso por médico, restricciones del portal del paciente y auditoría.
- Consultas, diagnósticos, signos vitales, recetas y órdenes compuestas.
- Transiciones de resultados, finalización, anulación y adendas.
- Bloqueo de eliminación con HTTP 405.
- Listados de diez módulos, navegación directa y recarga de React.
- Servir HTML y assets JavaScript correctamente, conservando JSON 404 en API inexistentes.
- Sin errores JavaScript ni respuestas 500 durante la navegación real del navegador.

Se usó únicamente `clinica_alejandra_unificado_test` con una cuenta temporal. Ambas se retiraron al terminar. Los registros clínicos existentes no se editaron ni eliminaron.

## Inicio local con la base existente

También se inició `npm start` en localhost:8080 con la conexión local privada existente: `/health`, login del administrador y listado de pacientes devolvieron HTTP 200. Las credenciales de esa conexión local están excluidas de Git y del contexto de Docker.

La evidencia de la prueba completa se guarda localmente en `.validation/report.json` y `.validation/unified-local.png`, excluidas del repositorio.

## Base nueva para Red Hat

Se validaron los recursos YAML de `deploy/mysql-demo.yaml` con un parser YAML. Se comprobó que el SQL embebido coincide con `sql/redhat-demo.sql` y que el servicio, la cuenta y el PVC coinciden con la configuración de la aplicación. El inicializador se ejecutó con un cliente simulado para comprobar carga inicial, reinicio sin reimportar y rechazo de tablas existentes sin modificar datos.

El SQL extraído del propio YAML se importó en `clinica_redhat_import_test`, una base temporal nueva de XAMPP. Se verificaron 15 pacientes, seis médicos, 15 historias, 24 consultas y 24 registros de signos vitales, sin consultas huérfanas. Se inició la aplicación existente contra esa base: salud HTTP 200, login de Alejandra con rol administrador y los tres listados con sus conteos correctos. Después se retiraron únicamente la base y cuenta de pruebas creadas para esta comprobación. Reporte local: `.validation/redhat-database-report.json`.

## Límites

No se construyó la imagen de contenedor en este equipo porque no dispone de Docker o Podman. Tampoco se aplicó el YAML al clúster: no hay sesión autenticada de `oc`. Al construir en Red Hat hay que comprobar disponibilidad del MySQL existente y que la cuenta integrada tenga acceso al esquema. Las pruebas locales no validan las credenciales de MySQL remoto.
