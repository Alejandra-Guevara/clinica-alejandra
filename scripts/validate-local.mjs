import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import net from 'node:net';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const root=fileURLToPath(new URL('../',import.meta.url));
const database='clinica_alejandra_unificado_test';
const databaseUser='clinica_unificado_test';
const mysqlClient=process.platform==='win32'?'C:/xampp/mysql/bin/mysql.exe':'mysql';
const requireBackend=createRequire(new URL('../backend/package.json',import.meta.url));
const requireFrontend=createRequire(new URL('../frontend/package.json',import.meta.url));
const mysql=requireBackend('mysql2/promise');
const bcrypt=requireBackend('bcrypt');
const {chromium,expect}=requireFrontend('@playwright/test');
let created=false,connection,server,browser;
const report={database,checks:[],started:new Date().toISOString()};
const check=name=>{report.checks.push(name);console.log(`OK: ${name}`);};

function rootSql(sql) {
  const result=spawnSync(mysqlClient,['-u','root','--default-character-set=utf8mb4','--batch','--skip-column-names'],{input:sql,encoding:'utf8',windowsHide:true});
  if(result.error)throw result.error;
  if(result.status!==0)throw new Error(`No se pudo preparar MySQL aislado: ${result.stderr}`);
  return result.stdout.trim();
}

try {
  assert.ok(!process.env.K_SERVICE&&!process.env.KUBERNETES_SERVICE_HOST,'Este verificador es exclusivamente local.');
  assert.ok(existsSync(join(root,'frontend/dist/index.html')),'Ejecuta npm run build primero.');
  assert.equal(rootSql(`SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='${database}';`),'0','La base de pruebas ya existe: no se modifica.');
  assert.equal(rootSql(`SELECT COUNT(*) FROM mysql.user WHERE User='${databaseUser}' AND Host='localhost';`),'0','La cuenta temporal ya existe: no se modifica.');
  const dbPassword=randomBytes(24).toString('hex');
  rootSql(`CREATE DATABASE \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
  created=true;
  rootSql(`CREATE USER '${databaseUser}'@'localhost' IDENTIFIED BY '${dbPassword}'; GRANT ALL PRIVILEGES ON \`${database}\`.* TO '${databaseUser}'@'localhost';`);
  rootSql(`USE \`${database}\`;\n${readFileSync(join(root,'sql/schema.sql'),'utf8')}`);
  Object.assign(process.env,{DB_HOST:'127.0.0.1',DB_PORT:'3306',DB_NAME:database,DB_USER:databaseUser,DB_PASSWORD:dbPassword,DB_SSL:'false'});

  for(const args of [['backend/scripts/migrate.js'],['--test','backend/tests/integration.test.js']]) {
    const result=spawnSync(process.execPath,args,{cwd:root,env:{...process.env,INTEGRATION_TESTS:'1'},stdio:'inherit',windowsHide:true});
    assert.equal(result.status,0,`Falló ${args.join(' ')}`);
  }
  check('Integración real de API, MySQL, permisos, consultas, recetas, resultados y portal');

  connection=await mysql.createConnection({host:'127.0.0.1',user:databaseUser,password:dbPassword,database,charset:'utf8mb4'});
  const uiPassword=`UI-${randomBytes(18).toString('hex')}-9A`;
  const [[role]]=await connection.execute("SELECT id_rol FROM roles WHERE nombre='Administrador'");
  const [admin]=await connection.execute('INSERT INTO usuarios(nombres,apellidos,email,password_hash) VALUES (?,?,?,?)',['Validación','Local','admin.ui@example.com',await bcrypt.hash(uiPassword,4)]);
  await connection.execute('INSERT INTO usuario_rol(id_usuario,id_rol) VALUES (?,?)',[admin.insertId,role.id_rol]);
  const [[doctor]]=await connection.execute('SELECT id_medico FROM medicos LIMIT 1');
  for(const [i,nombre] of ['Alba','Bruno'].entries()) {
    const [patient]=await connection.execute('INSERT INTO pacientes(tipo_documento,numero_documento,nombres,apellidos,fecha_nacimiento) VALUES (?,?,?,?,?)',['DEMO',`VALID-${i+1}`,nombre,'Validación','1990-02-02']);
    const [history]=await connection.execute('INSERT INTO historias_clinicas(id_paciente,numero_historia) VALUES (?,?)',[patient.insertId,`VALID-HC-${i+1}`]);
    await connection.execute('INSERT INTO historia_medico(id_historia,id_medico,asignado_por) VALUES (?,?,?)',[history.insertId,doctor.id_medico,admin.insertId]);
    await connection.execute('INSERT INTO consultas(id_historia,id_medico,fecha_hora,motivo_consulta,estado) VALUES (?,?,?,?,?)',[history.insertId,doctor.id_medico,'2026-02-01 10:00:00',`Control ${nombre}`,'finalizada']);
  }

  const probe=net.createServer();
  await new Promise(r=>probe.listen(0,'127.0.0.1',r));
  const port=probe.address().port;
  await new Promise(r=>probe.close(r));
  const base=`http://127.0.0.1:${port}`;
  server=spawn(process.execPath,['backend/src/server.js'],{cwd:root,env:{...process.env,PORT:String(port)},stdio:['ignore','pipe','pipe'],windowsHide:true});
  let startup='';
  server.stdout.on('data',data=>{startup+=data;});
  server.stderr.on('data',data=>{startup+=data;});
  let response;
  for(let i=0;i<60;i++) {
    try {response=await fetch(base+'/health');break;}catch {await new Promise(r=>setTimeout(r,100));}
  }
  assert.equal(response?.status,200,`No inició el servicio unificado: ${startup}`);
  assert.equal((await response.json()).frontend,true);
  const databaseResponse=await fetch(base+'/api/health');
  assert.equal(databaseResponse.status,200);
  assert.equal((await databaseResponse.json()).data.database,database);
  const index=await (await fetch(base)).text();
  const asset=index.match(/src="([^"]+\.js)"/)[1];
  const assetResponse=await fetch(base+asset);
  assert.equal(assetResponse.status,200);
  assert.match(assetResponse.headers.get('content-type'),/javascript/);
  assert.equal((await fetch(base+'/api/inexistente',{headers:{Accept:'text/html'}})).status,404);
  check('Un proceso y un puerto sirven HTML, JavaScript, API y conexión MySQL');

  browser=await chromium.launch({headless:true});
  const context=await browser.newContext({viewport:{width:1440,height:1000}});
  const page=await context.newPage();
  const pageErrors=[];
  const serverErrors=[];
  page.on('pageerror',error=>pageErrors.push(error.message));
  page.on('response',r=>{if(r.url().startsWith(base)&&r.status()>=500)serverErrors.push(`${r.status()} ${r.url()}`);});
  await page.goto(base+'/login');
  await page.getByPlaceholder('nombre@clinica.com').fill('admin.ui@example.com');
  await page.getByPlaceholder('Tu contraseña').fill(uiPassword);
  await page.locator('.login-submit').click();
  await expect(page.getByRole('link',{name:'Pacientes',exact:true})).toBeVisible();
  check('Login real y cookies CSRF/sesión bajo el mismo origen');

  await page.getByRole('link',{name:'Pacientes',exact:true}).click();
  await page.getByRole('textbox',{name:'Buscar',exact:true}).fill('VALID-1');
  await expect(page.getByText('Alba',{exact:true})).toBeVisible();
  await expect(page.getByText('Bruno',{exact:true})).toHaveCount(0);
  await page.getByRole('button',{name:'Ver detalle'}).click();
  await expect(page.getByRole('heading',{name:'Alba Validación',exact:true})).toBeVisible();
  await page.getByRole('tab',{name:/Consultas/}).click();
  await expect(page.getByText('Control Alba',{exact:true})).toBeVisible();
  await expect(page.getByText('Control Bruno',{exact:true})).toHaveCount(0);
  await page.getByRole('button',{name:'Cerrar ficha'}).click();
  check('Búsqueda y ficha clínica sin mezclar pacientes');

  await page.getByRole('button',{name:'Nuevo paciente'}).click();
  await page.locator('[name="tipo_documento"]').fill('DEMO');
  await page.locator('[name="numero_documento"]').fill('VALID-UI');
  await page.locator('[name="nombres"]').fill('Registro');
  await page.locator('[name="apellidos"]').fill('Navegador');
  await page.locator('[name="fecha_nacimiento"]').fill('1991-03-04');
  await page.getByRole('button',{name:'Guardar registro'}).click();
  await page.getByRole('textbox',{name:'Buscar',exact:true}).fill('VALID-UI');
  await expect(page.getByText('Registro',{exact:true})).toBeVisible();
  await page.getByRole('button',{name:'Editar',exact:true}).click();
  await page.locator('[name="telefono"]').fill('0000000000');
  await page.getByRole('button',{name:'Guardar registro'}).click();
  await expect(page.getByText('0000000000',{exact:true})).toBeVisible();
  const [[createdPatient]]=await connection.execute("SELECT telefono FROM pacientes WHERE numero_documento='VALID-UI'");
  assert.equal(createdPatient.telefono,'0000000000');
  check('Creación y edición desde React persistidas realmente en MySQL');

  for(const route of ['medicos','especialidades','historias-clinicas','consultas','diagnosticos','signos-vitales','medicamentos','recetas','examenes','ordenes-examen']) {
    await page.goto(base+'/'+route);
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('.notice-error')).toHaveCount(0);
  }
  await page.goto(base+'/pacientes');
  await expect(page.getByRole('heading',{name:'Pacientes',exact:true})).toBeVisible();
  await page.reload();
  await expect(page.getByRole('heading',{name:'Pacientes',exact:true})).toBeVisible();
  check('Listados de diez módulos, navegación directa y recarga SPA');
  assert.deepEqual(pageErrors,[],'Errores JavaScript en la página');
  assert.deepEqual(serverErrors,[],'Errores 500 durante la navegación');
  mkdirSync(join(root,'.validation'),{recursive:true});
  await page.screenshot({path:join(root,'.validation/unified-local.png'),fullPage:true});
  report.success=true;
  report.finished=new Date().toISOString();
  writeFileSync(join(root,'.validation/report.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
} catch(error) {
  console.error(error);
  process.exitCode=1;
} finally {
  if(browser)await browser.close();
  if(server) {server.kill();await new Promise(r=>server.exitCode!==null?r():server.once('exit',r));}
  if(connection)await connection.end();
  // Solo se retira el esquema temporal que este mismo proceso creó.
  if(created) {
    assert.equal(database,'clinica_alejandra_unificado_test');
    assert.ok(database.endsWith('_test'));
    rootSql(`DROP DATABASE \`${database}\`; DROP USER IF EXISTS '${databaseUser}'@'localhost';`);
    console.log('Base y cuenta temporales retiradas; la base clínica no se modificó.');
  }
}
