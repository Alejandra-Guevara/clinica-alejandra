# Crear y ver la base de datos en Red Hat

El servicio `clinica-alejandra` reúne React y Express. MySQL necesita su propio almacenamiento persistente. Crear MySQL no separa el frontend del backend ni requiere cambiar su URL.

## Escalar la aplicación

La aplicación usa sesiones compartidas entre réplicas con una clave fija de demostración incluida en el código. En el servicio Knative `clinica-alejandra`, se puede fijar un mínimo de dos instancias y un máximo de cuatro así:

```bash
oc patch ksvc clinica-alejandra -n maria-guevara-rio-dev --type=merge -p '{"spec":{"template":{"metadata":{"annotations":{"autoscaling.knative.dev/min-scale":"2","autoscaling.knative.dev/max-scale":"4"}}}}'
```

Knative conserva dos réplicas activas y agrega más cuando sube la cantidad de solicitudes simultáneas, hasta cuatro. Las cuotas disponibles del proyecto también limitan cuántos pods pueden ejecutarse.

MySQL debe conservarse en **una réplica** con su volumen actual. Duplicar el servidor MySQL sobre el mismo PVC no crea una base de datos redundante y puede dañar los archivos. Para varias instancias de base de datos se necesitaría configurar replicación o un clúster MySQL independiente, con almacenamiento para cada nodo.

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

## 2. Ver las tablas desde la terminal

Abre **>_** en la consola y entra al cliente MySQL dentro del pod:

```bash
oc exec -it deployment/historia-clinica-db -n maria-guevara-rio-dev -- mysql -h127.0.0.1 -u 'malejaguevara14@gmail.com' -p clinica-alejandra
```

Cuando pida la contraseña, escríbela y pulsa Enter. Luego puedes consultar:

```sql
SHOW TABLES;
SELECT numero_documento, nombres, apellidos FROM pacientes;
SELECT COUNT(*) FROM pacientes;
SELECT COUNT(*) FROM medicos;
SELECT COUNT(*) FROM consultas;
```

Los conteos iniciales esperados son **15**, **6** y **24**. Escribe `exit` para salir. El archivo [sql/redhat-demo.sql](sql/redhat-demo.sql) contiene el esquema y los ejemplos que se cargaron.

## 3. Comprobar la aplicación

Abre la URL de tu aplicación añadiendo `/api/health`:

```text
https://clinica-alejandra-maria-guevara-rio-dev.apps.rm3.7wse.p1.openshiftapps.com/api/health
```

Debe responder con HTTP 200 y:

```json
{"data":{"status":"ok","database":"clinica-alejandra"}}
```

En `/login`, entra con tu correo administrador y contraseña. En Pacientes deben aparecer los 15 ejemplos. Si la salud responde 503, revisa primero el pod y sus registros con los comandos anteriores.

## Conservación y respaldo

Apagar tu computador no apaga MySQL de Red Hat. El PVC conserva los datos cuando se reinicia el pod; eliminar el PVC o el proyecto sí puede eliminarlos. Developer Sandbox es un entorno temporal: conserva una copia de respaldo antes de que termine tu periodo. GitHub guarda el código y los ejemplos iniciales, no los registros nuevos que crees en Red Hat.

## Referencias

- [Imagen MySQL para OpenShift: inicialización y volumen de datos](https://github.com/sclorg/mysql-container/blob/master/8.4/root/usr/share/container-scripts/mysql/README.md).
- [Almacenamiento persistente en OpenShift](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/storage/understanding-persistent-storage).
- [Duración del Developer Sandbox](https://developers.redhat.com/developer-sandbox).
