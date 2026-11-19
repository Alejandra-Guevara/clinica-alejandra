// Configuración integrada exclusivamente para la demostración universitaria.
// Estas credenciales son públicas: no reutilizarlas en servicios reales.
export const demoConfig = Object.freeze({
  database: Object.freeze({
    host: 'historia-clinica-db',
    port: 3306,
    database: 'clinica-alejandra',
    user: 'malejaguevara14@gmail.com',
    password: 'Hola12345678',
    // MySQL interno del proyecto de demostración; no exige configurar TLS.
    ssl: false,
  }),
});
