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
