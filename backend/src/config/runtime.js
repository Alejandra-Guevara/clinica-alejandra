import 'dotenv/config';
import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { demoConfig } from './demo.js';

// PORT y K_SERVICE los proporciona OpenShift automáticamente. No hay variables
// que el usuario deba crear para ejecutar esta demostración en Red Hat.
export function createRuntimeConfig(platform = {}, localSettings = {}) {
  const inCluster = Boolean(platform.K_SERVICE || platform.KUBERNETES_SERVICE_HOST);
  const database = {...demoConfig.database};
  // Las herramientas locales de importación y pruebas conservan su conexión
  // opcional existente; nunca toman esos valores al ejecutarse en OpenShift.
  if(!inCluster) {
    Object.assign(database,localSettings);
    for(const [variable,field] of [['DB_HOST','host'],['DB_NAME','database'],['DB_USER','user'],['DB_PASSWORD','password']]) {
      if(platform[variable] !== undefined) database[field]=platform[variable];
    }
    if(platform.DB_PORT) database.port=Number(platform.DB_PORT);
    if(platform.DB_SSL !== undefined) database.ssl=platform.DB_SSL==='true';
    if(platform.DB_SSL_CA) database.caFile=platform.DB_SSL_CA;
  }
  return {
    port: Number(platform.PORT || 8080),
    // En el clúster todas las réplicas usan la misma firma para aceptar
    // sesiones emitidas por cualquiera de ellas. En local se genera una clave
    // aislada para cada proceso de desarrollo.
    sessionSecret: inCluster ? demoConfig.sessionSecret : randomBytes(48).toString('base64url'),
    secureCookies: inCluster,
    trustProxy: inCluster ? 1 : 0,
    database,
  };
}

export function validateRuntimeConfig(config) {
  if(!Number.isInteger(config.port)||config.port<1||config.port>65535) throw new Error('PORT debe ser un puerto válido');
}

const localFile=new URL('../../local.settings.json',import.meta.url);
const localSettings=!(process.env.K_SERVICE||process.env.KUBERNETES_SERVICE_HOST)&&existsSync(localFile)
  ? JSON.parse(readFileSync(localFile,'utf8')) : {};
export const runtimeConfig=createRuntimeConfig(process.env,localSettings);
