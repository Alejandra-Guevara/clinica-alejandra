# Crear y ver la base de datos en Red Hat

El servicio `clinica-alejandra` reúne React y Express. MySQL necesita su propio almacenamiento persistente. Crear MySQL no separa el frontend del backend ni requiere cambiar su URL. El panel Adminer es una herramienta opcional para ver las tablas, parecida a phpMyAdmin.

## 1. Crear MySQL con tablas y ejemplos

Estos pasos son para un proyecto sin MySQL previo. Si ya existe un servicio `historia-clinica-db` con información que quieras conservar, revisa esa instalación antes de aplicar este manifiesto; no borres sus volúmenes.

En el proyecto **maria-guevara-rio-dev**, abre **+ → Importar YAML**. Abre [deploy/mysql-demo.yaml](deploy/mysql-demo.yaml), copia el archivo completo en el editor y pulsa **Crear**. También puedes cargar ese archivo desde tu equipo.

Como alternativa, desde la terminal **>_** de Red Hat ejecuta:

```bash
oc apply -n maria-guevara-rio-dev -f https://raw.githubusercontent.com/Alejandra-Guevara/clinica-alejandra/main/deploy/mysql-demo.yaml
oc rollout status deployment/historia-clinica-db -n maria-guevara-rio-dev --timeout=600s
```

El YAML crea MySQL 8.4, el servicio interno `historia-clinica-db:3306`, un volumen persistente de 1 GiB y un inicializador. Los archivos de inicialización se montan individualmente para que la imagen de MySQL los encuentre al iniciar. La configuración está incluida; no debes crear variables ni Secrets manualmente. La imagen utiliza sus variables internas de inicialización, asignadas por el propio comando del YAML.

La primera inicialización crea el esquema `clinica-alejandra`, las tablas actualizadas, cuatro roles, el administrador Alejandra Rios, 15 pacientes, seis médicos, 15 historias y 24 consultas con sus registros relacionados: diagnósticos, signos vitales, recetas, medicamentos, alergias, antecedentes y exámenes. Las contraseñas de aplicación se guardan como hashes bcrypt. Todo el contenido clínico es sintético.

En **Cargas de trabajo → Pods**, el pod `historia-clinica-db-…` debe mostrar **Running / 1 de 1 listo**. En **Almacenamiento → PersistentVolumeClaims**, `historia-clinica-mysql-data` debe aparecer **Bound / Vinculado**. El primer arranque puede tardar unos minutos.

```bash
oc get pods -n maria-guevara-rio-dev -l app=historia-clinica-db
oc get pvc historia-clinica-mysql-data -n maria-guevara-rio-dev
oc logs deployment/historia-clinica-db -n maria-guevara-rio-dev --tail=50
```

Los registros del primer inicio incluyen: `Clínica inicializada: 15 pacientes, 6 médicos y 24 consultas.` Al reiniciar se conservan las tablas y los cambios; el inicializador no vuelve a importar los ejemplos. Si encuentra tablas anteriores sin su marca de instalación, se detiene para no sobrescribirlas. No borres el PVC para resolver ese caso.

## 2. Abrir un panel parecido a phpMyAdmin

Importa **otro YAML** con el contenido de [deploy/adminer.yaml](deploy/adminer.yaml), o ejecuta:

```bash
oc apply -n maria-guevara-rio-dev -f https://raw.githubusercontent.com/Alejandra-Guevara/clinica-alejandra/main/deploy/adminer.yaml
oc rollout status deployment/clinica-db-admin -n maria-guevara-rio-dev --timeout=300s
oc get route clinica-db-admin -n maria-guevara-rio-dev -o jsonpath='https://{.spec.host}{"\n"}'
```

Abre el enlace HTTPS que imprima el último comando. También aparece en **Redes → Rutas → clinica-db-admin**. Es una URL del panel; la aplicación conserva su dirección actual.

En Adminer introduce:

| Campo | Valor |
| --- | --- |
| Sistema | MySQL |
| Servidor | `historia-clinica-db` |
| Usuario | `malejaguevara14@gmail.com` |
| Contraseña | `Hola12345678` |
| Base de datos | `clinica-alejandra` |

Pulsa **Entrar / Login**. Verás las tablas; abre `pacientes` y pulsa **Seleccionar datos** para consultar los registros. En **Comando SQL** puedes ejecutar:

```sql
SELECT numero_documento, nombres, apellidos FROM pacientes;
SELECT COUNT(*) AS pacientes FROM pacientes;
SELECT COUNT(*) AS medicos FROM medicos;
SELECT COUNT(*) AS consultas FROM consultas;
```

Los conteos iniciales esperados son **15**, **6** y **24**. El archivo [sql/redhat-demo.sql](sql/redhat-demo.sql) contiene el mismo esquema y datos embebidos en el YAML; no necesitas importarlo otra vez.

## 3. Comprobar la aplicación

Abre la URL de tu aplicación añadiendo `/api/health`:

```text
https://clinica-alejandra-maria-guevara-rio-dev.apps.rm3.7wse.p1.openshiftapps.com/api/health
```

Debe responder con HTTP 200 y:

```json
{"data":{"status":"ok","database":"clinica-alejandra"}}
```

En `/login`, entra con `malejaguevara14@gmail.com` y `Hola12345678`. En Pacientes deben aparecer los 15 ejemplos. Crea un paciente desde la aplicación, recarga y consulta `pacientes` en Adminer para verificar que se guardó en MySQL. Si la salud responde 503, revisa primero el pod y sus registros con los comandos anteriores.

## Conservación y respaldo

Apagar tu computador no apaga MySQL de Red Hat. El PVC conserva los datos cuando se reinicia el pod; eliminar el PVC o el proyecto sí puede eliminarlos. Developer Sandbox es un entorno temporal: exporta un respaldo desde **Exportar** en Adminer antes de que termine tu periodo. GitHub guarda el código y los ejemplos iniciales, no los registros nuevos que crees en Red Hat.

Si ya no necesitas el panel, puedes retirarlo sin tocar MySQL ni su PVC:

```bash
oc delete deployment/clinica-db-admin service/clinica-db-admin route/clinica-db-admin -n maria-guevara-rio-dev
```

## Referencias

- [Imagen MySQL para OpenShift: inicialización y volumen de datos](https://github.com/sclorg/mysql-container/blob/master/8.4/root/usr/share/container-scripts/mysql/README.md).
- [Imagen oficial de Adminer](https://hub.docker.com/_/adminer).
- [Almacenamiento persistente en OpenShift](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/storage/understanding-persistent-storage).
- [Duración del Developer Sandbox](https://developers.redhat.com/developer-sandbox).
