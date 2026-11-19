# Clínica Alejandra: un repositorio y un despliegue

React y Express se ejecutan como una sola aplicación: **un Dockerfile, una imagen, un contenedor, un proceso Node, un puerto 8080 y una URL pública**. Express sirve los archivos de React y los endpoints `/api`. No se necesita Nginx, otro frontend publicado, una URL de backend separada ni variables de entorno manuales.

El repositorio reúne el frontend restaurado `157db93` y el backend restaurado `3de1725`, adaptados para trabajar juntos. Los dos repositorios anteriores se conservan.

```text
frontend/       Interfaz React/Vite y sus pruebas
backend/        Express, autenticación, MySQL, scripts y migraciones
sql/schema.sql  Esquema original para una base vacía
Dockerfile      Construye React y lo incluye en el servidor Express
deploy/         Un solo Deployment de OpenShift
scripts/        Validación local automatizada
```

## Red Hat: importar desde Git

1. Selecciona el proyecto `maria-guevara-rio-dev`.
2. Abre **+ → Importar desde Git** y pega `https://github.com/Alejandra-Guevara/clinica-alejandra.git`.
3. Selecciona estrategia **Dockerfile**, ruta `Dockerfile`, rama `main` y directorio de contexto `/` (raíz del repositorio).
4. Usa el nombre **clinica-alejandra**, tipo de recurso **Deployment** y puerto **8080**. Activa una Route con TLS **edge** y redirección de HTTP a HTTPS.
5. No agregues variables, Secrets ni ConfigMaps. Espera a que termine la compilación y abre la URL que dé la Route.

En esa misma dirección se accede a React y a `/api`. El puerto que la plataforma suministra automáticamente también se admite, sin configurarlo a mano. El despliegue usa un solo pod porque la firma de sesión se genera en memoria; tras reiniciar, vuelve a iniciar sesión.

## Red Hat: importar el YAML para la clase

El archivo [deploy/openshift.yaml](deploy/openshift.yaml) contiene ImageStream, BuildConfig con el repositorio Git, **un único Deployment con un contenedor**, Service y Route. Es la alternativa al formulario de Git. El nombre `clinica-alejandra` es distinto al de los dos despliegues anteriores.

Para aplicarlo y compilar desde la terminal `>_`:

```bash
curl -fsS https://raw.githubusercontent.com/Alejandra-Guevara/clinica-alejandra/main/deploy/deploy-redhat.sh -o /tmp/deploy-clinica.sh
bash /tmp/deploy-clinica.sh
```

El script no crea otro frontend o backend, no modifica los servicios antiguos y no cambia MySQL. Si ya creaste un servicio Serverless con el mismo nombre, se detiene para evitar duplicar su Route.

## Base de datos existente

La configuración académica está integrada en [backend/src/config/demo.js](backend/src/config/demo.js): servicio MySQL `historia-clinica-db:3306`, esquema `clinica-alejandra` y la cuenta de demostración proporcionada por la propietaria. No hay una URL de frontend fija porque todo comparte origen. La conexión interna de esta demostración no exige TLS.

**MySQL sigue siendo el servicio de almacenamiento existente**, independiente del contenedor de la aplicación. No se crea otro MySQL al desplegar. La cuenta debe existir en MySQL y tener permisos sobre ese esquema; el correo de login de la aplicación y el usuario MySQL son cuentas diferentes. La configuración contiene credenciales públicas solo por petición expresa para este proyecto académico; no reutilizarla en servicios reales.

El despliegue no importa ni elimina tablas o datos. Para un esquema vacío, importa `sql/schema.sql` con una cuenta autorizada y aplica las migraciones con `npm run db:migrate`. En un contenedor puede ejecutarse `oc exec deployment/clinica-alejandra -- npm run db:migrate`, siempre que la cuenta tenga permisos DDL. Los datos sintéticos y su verificador se conservan en `backend/scripts`; su cargador original mantiene la restricción de ejecución local y nunca se ejecuta al iniciar la aplicación.

La cuenta del administrador de la aplicación no se reinicia ni se modifica. Usa la que exista en la base importada.

## Uso local

Requiere Node 22 o posterior y MySQL. Desde la raíz:

```powershell
npm run setup
npm run build
npm start
```

Abre `http://localhost:8080`. Es un único servidor para la página y la API. Para la conexión local puede usarse un archivo privado opcional `backend/local.settings.json` con `host`, `port`, `database`, `user`, `password` y `ssl`; se ignora en Git, en la imagen y en OpenShift. En el equipo de trabajo se prepara con la cuenta local existente, sin publicar sus credenciales. Las utilidades locales también conservan sus opciones de conexión para pruebas aisladas.

Para editar React con recarga rápida puedes usar `npm run dev --prefix frontend`; Vite reenvía `/api` al servidor local 8080. Esto es solo una herramienta de desarrollo: el despliegue usa el React compilado y un proceso.

## Comprobaciones

- `/health`: React compilado y Express disponibles. Se usa para disponibilidad del contenedor.
- `/api/live`: Express disponible, sin depender de MySQL. Se usa para comprobar que el proceso vive.
- `/api/health`: conexión con MySQL; devuelve 503 si falla la cuenta, el host o el esquema. No oculta una base desconectada.
- `/login`, `/pacientes`, `/consultas`: rutas de React que también funcionan al recargar.
- Una ruta `/api` inexistente sigue devolviendo JSON 404, no HTML.

La página puede abrirse aunque MySQL esté desconectado, pero el login y los registros requieren una conexión válida. Configurar una cuenta en el código no la crea dentro de MySQL.

## Validación local automatizada

```powershell
npm run build
npm run lint
npm test
npm run validate:local
npm run test:e2e
```

`validate:local` necesita XAMPP local con el cliente `C:/xampp/mysql/bin/mysql.exe` y una cuenta root local autorizada para crear una base de pruebas. Crea únicamente `clinica_alejandra_unificado_test`, aplica el SQL y migraciones, ejecuta integración HTTP/MySQL y abre Chromium contra la aplicación completa. Si ese esquema ya existe, se detiene para no modificarlo. Al terminar retira únicamente la base y cuenta temporales creadas por el verificador.

Comprueba login, permisos, pacientes separados, alta y edición persistidas, módulos clínicos, archivos JavaScript y navegación SPA. Guarda evidencia local en `.validation/`, excluida de Git. No utiliza ni altera los registros de `clinica-alejandra`.

Las pruebas locales no sustituyen construir la imagen ni verificar permisos, cuotas y MySQL en tu clúster Red Hat.
