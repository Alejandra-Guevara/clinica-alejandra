import express from 'express';
import { existsSync } from 'node:fs';
import { extname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const frontendDirectory=fileURLToPath(new URL('../../frontend/dist/',import.meta.url));

export function attachFrontend(app,directory=frontendDirectory) {
  const index=join(directory,'index.html');
  app.get('/health',(_req,res)=>{
    const ready=existsSync(index);
    res.status(ready?200:503).json({status:ready?'ok':'frontend_not_built',frontend:ready,backend:true});
  });
  app.use(express.static(directory,{
    index:false,
    redirect:false,
    setHeaders(res,path) {
      res.setHeader('Cache-Control',path.includes('/assets/')||path.includes('\\assets\\')
        ? 'public, max-age=31536000, immutable' : 'no-cache');
    },
  }));
  app.use((req,res,next)=>{
    if(!['GET','HEAD'].includes(req.method)||!req.accepts('html')||extname(req.path)) return next();
    if(!existsSync(index)) return res.status(503).json({error:{code:'FRONTEND_NOT_BUILT',message:'Ejecuta npm run build antes de iniciar la página.'}});
    return res.sendFile(index,{headers:{'Cache-Control':'no-cache'}});
  });
}
