#!/data/data/com.termux/files/usr/bin/bash
# Uso (dentro da pasta do projeto): bash painel.sh
set -e
mkdir -p painel

# ---------- catálogo de visuais ----------
cat > painel/visuais.json <<'EOF_VIS'
[
  { "id": 1, "nome": "Abertura: terreno", "emoji": "⛰️" },
  { "id": 2, "nome": "Chuva e recarga", "emoji": "🌧️" },
  { "id": 3, "nome": "Camadas e aquífero", "emoji": "🧱" },
  { "id": 4, "nome": "Poço jorrando", "emoji": "⛲" }
]
EOF_VIS

# ---------- servidor ----------
cat > painel/server.js <<'EOF_SRV'
const http = require("http");
const fs = require("fs");
const path = require("path");
const { execFile } = require("child_process");

const raiz = path.join(__dirname, "..");
const roteiroPath = path.join(raiz, "roteiro.json");
const PORTA = 8080;

const git = (args) =>
  new Promise((res) =>
    execFile(
      "git",
      args,
      { cwd: raiz, timeout: 120000, env: { ...process.env, GIT_TERMINAL_PROMPT: "0" } },
      (err, so, se) => res({ ok: !err, out: (so || "") + (se || "") })
    )
  );

const lerJson = (p, padrao) => {
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch (e) {
    return padrao;
  }
};

const corpo = (req) =>
  new Promise((res) => {
    let d = "";
    req.on("data", (c) => (d += c));
    req.on("end", () => {
      try {
        res(JSON.parse(d || "{}"));
      } catch (e) {
        res({});
      }
    });
  });

const responder = (res, codigo, tipo, texto) => {
  res.writeHead(codigo, { "Content-Type": tipo + "; charset=utf-8" });
  res.end(texto);
};

http
  .createServer(async (req, res) => {
    if (req.method === "GET" && req.url === "/") {
      return responder(res, 200, "text/html", fs.readFileSync(path.join(__dirname, "index.html"), "utf8"));
    }

    if (req.method === "GET" && req.url === "/api/estado") {
      const r = await git(["remote", "get-url", "origin"]);
      let repo = r.ok ? r.out.trim().replace(/\.git$/, "") : "";
      return responder(
        res,
        200,
        "application/json",
        JSON.stringify({
          roteiro: lerJson(roteiroPath, { titulo: "", cenas: [] }),
          visuais: lerJson(path.join(__dirname, "visuais.json"), []),
          actions: repo ? repo + "/actions" : "",
        })
      );
    }

    if (req.method === "POST" && req.url === "/api/gerar") {
      const b = await corpo(req);
      let saida = "";
      if (Array.isArray(b.cenas) && b.cenas.length > 0) {
        const cenas = b.cenas.map((c) => ({
          texto: String(c.texto || "").slice(0, 300),
          segundos: Math.min(30, Math.max(1, Number(c.segundos) || 4)),
          visual: Number(c.visual) || 0,
        }));
        const titulo = String(b.titulo || "").trim() || "Short";
        fs.writeFileSync(roteiroPath, JSON.stringify({ titulo, cenas }, null, 2));
        saida += "Roteiro salvo.\n";
      } else {
        saida += "Sem mudanças no roteiro: usando o que já existe.\n";
      }
      await git(["add", "-A"]);
      let c = await git(["commit", "-m", "painel"]);
      if (!c.ok) c = await git(["commit", "--allow-empty", "-m", "painel"]);
      saida += c.out;
      const p = await git(["push"]);
      saida += p.out;
      return responder(res, 200, "application/json", JSON.stringify({ ok: p.ok, saida }));
    }

    responder(res, 404, "text/plain", "Nao encontrado");
  })
  .listen(PORTA, "127.0.0.1", () => {
    console.log("\n🎬 Painel rodando! Abra no navegador:");
    console.log("   http://localhost:" + PORTA);
    console.log("(deixe o Termux aberto; CTRL+C para fechar)\n");
    execFile("termux-open-url", ["http://localhost:" + PORTA], () => {});
  });
EOF_SRV

# ---------- interface ----------
cat > painel/index.html <<'EOF_HTML'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Painel de Shorts</title>
<style>
  :root { --roxo:#7c3aed; --rosa:#ec4899; --azul:#0ea5e9; --verde:#22c55e; --laranja:#f59e0b; }
  * { box-sizing: border-box; }
  body { margin:0; font-family: system-ui, sans-serif; color:#1f2340;
         background: linear-gradient(160deg,#ede9fe,#fce7f3 50%,#e0f2fe); min-height:100vh; padding-bottom:150px; }
  header { padding:22px 18px 14px; text-align:center; background: linear-gradient(90deg,var(--roxo),var(--rosa));
           color:white; border-radius:0 0 28px 28px; box-shadow:0 8px 24px rgba(124,58,237,.35); }
  header h1 { margin:0; font-size:26px; }
  header p { margin:6px 0 0; opacity:.9; font-size:14px; }
  main { padding:16px; max-width:640px; margin:0 auto; }
  .card { background:white; border-radius:20px; padding:16px; margin-bottom:16px; box-shadow:0 4px 16px rgba(0,0,0,.08); }
  .card h2 { margin:0 0 4px; font-size:18px; }
  .card small { color:#6b7280; display:block; margin-bottom:10px; }
  .opc { font-size:11px; background:#f3f4f6; color:#6b7280; padding:2px 8px; border-radius:10px; vertical-align:middle; margin-left:6px; }
  input, textarea { width:100%; font:inherit; padding:12px; border:2px solid #e5e7eb; border-radius:14px; background:#fafafa; }
  input:focus, textarea:focus { outline:none; border-color:var(--roxo); background:white; }
  textarea { min-height:80px; resize:vertical; }
  button { font:inherit; border:none; cursor:pointer; border-radius:14px; padding:12px 16px; font-weight:700; color:white; }
  .b-roxo { background:var(--roxo); } .b-azul { background:var(--azul); } .b-verde { background:var(--verde); }
  .b-laranja { background:var(--laranja); } .b-cinza { background:#e5e7eb; color:#374151; }
  .linha { display:flex; gap:8px; flex-wrap:wrap; margin-top:10px; }
  .linha button { flex:1; }
  .cena { border:2px solid #ede9fe; border-radius:16px; padding:12px; margin-bottom:12px; background:#faf5ff; }
  .topo { display:flex; justify-content:space-between; align-items:center; margin-bottom:8px; }
  .topo button { padding:6px 10px; background:#e9d5ff; color:#5b21b6; margin-left:4px; }
  .seg { display:flex; align-items:center; gap:10px; margin:10px 0; font-weight:700; }
  .seg button { padding:6px 14px; background:var(--azul); font-size:18px; }
  .chips { display:flex; flex-wrap:wrap; gap:8px; }
  .chip { padding:8px 12px; border-radius:20px; background:white; border:2px solid #e5e7eb; color:#374151; font-size:14px; }
  .chip.on { background:var(--rosa); border-color:var(--rosa); color:white; }
  .barra { position:fixed; left:0; right:0; bottom:0; padding:12px 16px 16px; background:rgba(255,255,255,.95);
           box-shadow:0 -6px 20px rgba(0,0,0,.1); border-radius:22px 22px 0 0; }
  .barra .grande { width:100%; font-size:20px; padding:16px; background:linear-gradient(90deg,var(--verde),var(--azul)); }
  #status { margin-top:8px; font-size:14px; text-align:center; min-height:20px; }
  #status a { color:var(--roxo); font-weight:800; }
  details { margin-top:6px; font-size:12px; color:#6b7280; white-space:pre-wrap; }
</style>
</head>
<body>
<header>
  <h1>🎬 Painel de Shorts</h1>
  <p>Tudo é opcional. Preencha só o que quiser.</p>
</header>
<main>

  <div class="card">
    <h2>🏷️ Tema <span class="opc">opcional</span></h2>
    <small>Vira o título do vídeo.</small>
    <input id="tema" placeholder="Ex.: Poço Artesiano">
  </div>

  <div class="card">
    <h2>🤖 Pedido para a IA <span class="opc">opcional</span></h2>
    <small>Escreva o que quer. Copie o pedido, mande no chat e cole a resposta aqui embaixo.</small>
    <textarea id="prompt" placeholder="Ex.: vídeo curto e animado, com uma curiosidade no final"></textarea>
    <div class="linha">
      <button class="b-roxo" onclick="copiarPedido()">📋 Copiar pedido</button>
    </div>
    <textarea id="pedido" readonly style="display:none;margin-top:10px;min-height:120px"></textarea>
    <small style="margin-top:14px">Resposta da IA (JSON):</small>
    <textarea id="resposta" placeholder="Cole aqui a resposta da IA"></textarea>
    <div class="linha">
      <button class="b-azul" onclick="aplicarResposta()">📥 Aplicar resposta</button>
    </div>
  </div>

  <div class="card">
    <h2>📝 Roteiro e Visual <span class="opc">opcional</span></h2>
    <small>Escreva as cenas e escolha o visual de cada uma.</small>
    <div id="cenas"></div>
    <div class="linha">
      <button class="b-laranja" onclick="novaCena()">➕ Nova cena</button>
    </div>
  </div>

</main>

<div class="barra">
  <button class="grande" id="btnGerar" onclick="gerar()">🚀 Gerar vídeo</button>
  <div id="status"></div>
</div>

<script>
let cenas = [];
let visuais = [];
let actions = "";

const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const $ = (id) => document.getElementById(id);

function desenhar() {
  const opcoes = [{ id: 0, nome: "Só texto", emoji: "📝" }, ...visuais];
  $("cenas").innerHTML = cenas.map((c, i) => `
    <div class="cena">
      <div class="topo"><b>Cena ${i + 1}</b>
        <span><button onclick="mover(${i},-1)">↑</button><button onclick="mover(${i},1)">↓</button><button onclick="remover(${i})">🗑</button></span>
      </div>
      <textarea oninput="cenas[${i}].texto=this.value" placeholder="Texto que aparece nesta cena">${esc(c.texto)}</textarea>
      <div class="seg">⏱ <button onclick="tempo(${i},-1)">−</button> <span>${c.segundos}s</span> <button onclick="tempo(${i},1)">+</button></div>
      <div class="chips">
        ${opcoes.map((o) => `<button class="chip ${Number(c.visual) === o.id ? "on" : ""}" onclick="escolher(${i},${o.id})">${o.emoji} ${esc(o.nome)}</button>`).join("")}
      </div>
    </div>`).join("") || "<small>Nenhuma cena ainda. Toque em “Nova cena”.</small>";
}

function novaCena() { cenas.push({ texto: "", segundos: 4, visual: 0 }); desenhar(); }
function remover(i) { cenas.splice(i, 1); desenhar(); }
function mover(i, d) { const j = i + d; if (j < 0 || j >= cenas.length) return; [cenas[i], cenas[j]] = [cenas[j], cenas[i]]; desenhar(); }
function tempo(i, d) { cenas[i].segundos = Math.min(30, Math.max(1, Number(cenas[i].segundos) + d)); desenhar(); }
function escolher(i, id) { cenas[i].visual = id; desenhar(); }

function montarPedido() {
  const lista = visuais.map((v) => `${v.id} = ${v.nome}`).join(", ");
  return `Crie o roteiro de um Short vertical animado (Remotion).
Tema: ${$("tema").value || "(escolha você)"}
Pedido: ${$("prompt").value || "(sem pedido extra)"}

Visuais disponíveis: 0 = só texto, ${lista}.
Se nenhum visual combinar com o tema, use 0 e me diga qual visual novo precisa ser criado.

Responda SOMENTE com JSON neste formato:
{"titulo":"...","cenas":[{"texto":"...","segundos":4,"visual":0}]}`;
}

async function copiarPedido() {
  const t = $("pedido");
  t.value = montarPedido();
  t.style.display = "block";
  try { await navigator.clipboard.writeText(t.value); $("status").textContent = "Pedido copiado! Cole no chat com a IA."; }
  catch (e) { t.select(); document.execCommand("copy"); $("status").textContent = "Pedido copiado! Cole no chat com a IA."; }
}

function aplicarResposta() {
  try {
    const txt = $("resposta").value.replace(/```json|```/g, "").trim();
    const j = JSON.parse(txt);
    if (!Array.isArray(j.cenas)) throw new Error("sem cenas");
    cenas = j.cenas.map((c) => ({ texto: c.texto || "", segundos: Number(c.segundos) || 4, visual: Number(c.visual) || 0 }));
    if (j.titulo) $("tema").value = j.titulo;
    desenhar();
    $("status").textContent = "Resposta aplicada! Confira as cenas e toque em Gerar.";
  } catch (e) {
    $("status").textContent = "Não consegui ler o JSON. Cole só a resposta da IA.";
  }
}

async function gerar() {
  const btn = $("btnGerar");
  btn.disabled = true;
  $("status").textContent = "⏳ Salvando e enviando...";
  try {
    const r = await fetch("/api/gerar", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ titulo: $("tema").value, cenas }),
    });
    const j = await r.json();
    const link = actions ? ` <a href="${esc(actions)}" target="_blank">Abrir Actions ↗</a>` : "";
    $("status").innerHTML = (j.ok ? "✅ Enviado! O vídeo está sendo renderizado." + link
      : "⚠️ O envio falhou. Veja o detalhe abaixo.") + `<details><summary>detalhes</summary>${esc(j.saida)}</details>`;
  } catch (e) {
    $("status").textContent = "Erro ao falar com o painel. Ele ainda está aberto no Termux?";
  }
  btn.disabled = false;
}

(async function iniciar() {
  const e = await (await fetch("/api/estado")).json();
  visuais = e.visuais;
  actions = e.actions;
  cenas = (e.roteiro.cenas || []).map((c) => ({ texto: c.texto, segundos: c.segundos, visual: c.visual || 0 }));
  $("tema").value = e.roteiro.titulo || "";
  desenhar();
})();
</script>
</body>
</html>
EOF_HTML

# ---------- workflow: renderiza a cada push ----------
cat > .github/workflows/render.yml <<'EOF_YML'
name: Render Short
on:
  workflow_dispatch:
  push:

jobs:
  render:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm install
      - run: npm run render
      - uses: actions/upload-artifact@v4
        with:
          name: short
          path: out/short.mp4
EOF_YML

# ---------- comando "visual" ----------
DIR="$PWD"
printf '#!/data/data/com.termux/files/usr/bin/bash\ncd "%s" && node painel/server.js\n' "$DIR" > "$PREFIX/bin/visual"
chmod +x "$PREFIX/bin/visual"

echo ""
echo "Pronto! Agora é só digitar:  visual"
