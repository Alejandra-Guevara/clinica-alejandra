import test from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import { mkdtemp, mkdir, writeFile, unlink, rmdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { attachFrontend } from '../src/web.js';
import { notFound } from '../src/middlewares/errors.js';

test('one HTTP server serves React navigation and assets while preserving API 404 responses',async()=>{
  const dir=await mkdtemp(join(tmpdir(),'clinica-web-'));
  await mkdir(join(dir,'assets'));
  await writeFile(join(dir,'index.html'),'<!doctype html><title>Clinica unificada</title>');
  await writeFile(join(dir,'assets','example.js'),'console.log("asset")');
  const app=express();
  app.get('/api/live',(_req,res)=>res.json({status:'ok'}));
  app.use('/api',notFound);
  attachFrontend(app,dir);
  app.use(notFound);
  const server=app.listen(0,'127.0.0.1');
  await new Promise(r=>server.once('listening',r));
  const base=`http://127.0.0.1:${server.address().port}`;
  try {
    for(const route of ['/','/login','/pacientes']) {
      const response=await fetch(base+route,{headers:{Accept:'text/html'}});
      assert.equal(response.status,200);
      assert.ok((await response.text()).includes('Clinica unificada'));
      assert.equal(response.headers.get('cache-control'),'no-cache');
    }
    const asset=await fetch(base+'/assets/example.js');
    assert.equal(asset.status,200);
    assert.match(asset.headers.get('content-type'),/javascript/);
    assert.match(asset.headers.get('cache-control'),/immutable/);
    assert.equal((await fetch(base+'/assets/missing.js')).status,404);
    const missing=await fetch(base+'/api/missing',{headers:{Accept:'text/html'}});
    assert.equal(missing.status,404);
    assert.equal((await missing.json()).error.code,'NOT_FOUND');
    assert.equal((await fetch(base+'/api/live')).status,200);
    assert.deepEqual(await (await fetch(base+'/health')).json(),{status:'ok',frontend:true,backend:true});
  } finally {
    await new Promise(r=>server.close(r));
    await unlink(join(dir,'assets','example.js'));
    await unlink(join(dir,'index.html'));
    await rmdir(join(dir,'assets'));
    await rmdir(dir);
  }
});
