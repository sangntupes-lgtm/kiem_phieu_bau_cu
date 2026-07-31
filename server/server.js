const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });
app.use(cors());
app.use(express.json({ limit: '1mb' }));

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const DATA_FILE = path.join(DATA_DIR, 'db.json');
fs.mkdirSync(DATA_DIR, { recursive: true });
let db = { elections: {} };
try { db = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8')); } catch (_) {}
const save = () => fs.writeFileSync(DATA_FILE, JSON.stringify(db, null, 2));
const id = () => crypto.randomUUID();
const key = () => crypto.randomBytes(18).toString('hex');
const code = () => {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let c; do { c = Array.from({length:6},()=>chars[Math.floor(Math.random()*chars.length)]).join(''); } while (db.elections[c]);
  return c;
};
const owner = (req, e) => req.get('x-owner-key') && req.get('x-owner-key') === e.ownerKey;
const out = (e, includeKey=false) => ({
  code:e.code,name:e.name,unit:e.unit,maxChoices:e.maxChoices,locked:e.locked,totalBallots:e.ballots.length,
  candidates:e.candidates.map(c=>({...c,votes:e.ballots.filter(b=>b.selected.includes(c.id)).length})),
  ...(includeKey?{ownerKey:e.ownerKey}:{})
});
const emit = (c) => io.to(c).emit('election-updated', {code:c});

app.get('/health', (_,res)=>res.json({ok:true,time:new Date().toISOString()}));
app.post('/api/elections', (req,res)=>{
  const name=String(req.body.name||'').trim(); if(!name) return res.status(400).json({error:'Thiếu tên cuộc bầu cử.'});
  const c=code(); const e={code:c,ownerKey:key(),name,unit:String(req.body.unit||''),maxChoices:Math.max(1,Number(req.body.maxChoices)||1),locked:false,candidates:[],ballots:[],logs:[],createdAt:new Date().toISOString()};
  db.elections[c]=e; save(); res.status(201).json(out(e,true));
});
app.get('/api/elections/:code',(req,res)=>{const e=db.elections[req.params.code.toUpperCase()]; if(!e)return res.status(404).json({error:'Không tìm thấy cuộc bầu cử.'}); res.json(out(e,owner(req,e)));});
app.post('/api/elections/:code/candidates',(req,res)=>{const e=db.elections[req.params.code.toUpperCase()]; if(!e)return res.status(404).json({error:'Không tìm thấy.'}); if(!owner(req,e))return res.status(403).json({error:'Không có quyền chủ cuộc bầu cử.'}); const name=String(req.body.name||'').trim(); if(!name)return res.status(400).json({error:'Tên không hợp lệ.'}); e.candidates.push({id:id(),name,sortOrder:e.candidates.length+1}); save(); emit(e.code); res.json(out(e,true));});
app.delete('/api/elections/:code/candidates/:id',(req,res)=>{const e=db.elections[req.params.code.toUpperCase()]; if(!e)return res.status(404).json({error:'Không tìm thấy.'}); if(!owner(req,e))return res.status(403).json({error:'Không có quyền.'}); if(e.ballots.length)return res.status(409).json({error:'Không thể xóa ứng cử viên sau khi đã nhập phiếu.'}); e.candidates=e.candidates.filter(c=>c.id!==req.params.id).map((c,i)=>({...c,sortOrder:i+1})); save(); emit(e.code); res.json(out(e,true));});
app.post('/api/elections/:code/ballots',(req,res)=>{const e=db.elections[req.params.code.toUpperCase()]; if(!e)return res.status(404).json({error:'Không tìm thấy.'}); if(e.locked)return res.status(423).json({error:'Cuộc bầu cử đã khóa.'}); const selected=[...new Set((req.body.selected||[]).map(String))]; if(selected.length<1||selected.length>e.maxChoices)return res.status(400).json({error:`Phiếu phải chọn từ 1 đến ${e.maxChoices} người.`}); if(selected.some(x=>!e.candidates.find(c=>c.id===x)))return res.status(400).json({error:'Phiếu chứa lựa chọn không hợp lệ.'}); e.ballots.push({id:id(),selected,createdAt:new Date().toISOString()}); save(); emit(e.code); res.status(201).json(out(e,false));});
app.patch('/api/elections/:code',(req,res)=>{const e=db.elections[req.params.code.toUpperCase()]; if(!e)return res.status(404).json({error:'Không tìm thấy.'}); if(!owner(req,e))return res.status(403).json({error:'Không có quyền.'}); if(typeof req.body.locked==='boolean')e.locked=req.body.locked; save(); emit(e.code); res.json(out(e,true));});
app.delete('/api/elections/:code',(req,res)=>{const c=req.params.code.toUpperCase(),e=db.elections[c]; if(!e)return res.status(404).json({error:'Không tìm thấy.'}); if(!owner(req,e))return res.status(403).json({error:'Không có quyền.'}); delete db.elections[c]; save(); emit(c); res.json({ok:true});});

io.on('connection', s=>s.on('join-election', c=>s.join(String(c).toUpperCase())));
const port=process.env.PORT||3000; server.listen(port,()=>console.log(`Server running on :${port}`));
