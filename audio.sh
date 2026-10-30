#!/data/data/com.termux/files/usr/bin/bash
# Uso (dentro da pasta do projeto): bash audio.sh
set -e
mkdir -p scripts

# ---------- gerador de narração (roda no GitHub Actions) ----------
cat > scripts/narrar.py <<'EOF_PY'
import asyncio
import json
import math
import os
import sys

import edge_tts
from mutagen.mp3 import MP3

with open("roteiro.json", encoding="utf-8") as f:
    r = json.load(f)

if r.get("narracao") is False:
    print("Narração desligada.")
    sys.exit(0)

voz = r.get("voz", "pt-BR-FranciscaNeural")
os.makedirs("public/audio", exist_ok=True)


async def main():
    for i, c in enumerate(r["cenas"]):
        texto = (c.get("texto") or "").strip()
        if not texto:
            continue
        arq = f"public/audio/cena{i + 1}.mp3"
        try:
            await edge_tts.Communicate(texto, voz).save(arq)
            dur = MP3(arq).info.length
        except Exception as e:
            print(f"Falha na narração da cena {i + 1}: {e}")
            continue
        c["audio"] = f"audio/cena{i + 1}.mp3"
        c["segundos"] = max(int(c.get("segundos", 4)), math.ceil(dur + 0.6))
        print(f"Cena {i + 1}: {dur:.1f}s de fala -> {c['segundos']}s")


asyncio.run(main())

with open("roteiro.json", "w", encoding="utf-8") as f:
    json.dump(r, f, ensure_ascii=False, indent=2)
EOF_PY

# ---------- workflow com narração ----------
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
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install edge-tts mutagen
      - run: python scripts/narrar.py
      - run: npm install
      - run: npm run render
      - uses: actions/upload-artifact@v4
        with:
          name: short
          path: out/short.mp4
EOF_YML

# ---------- vídeo: toca o áudio de cada cena ----------
cat > src/Short.jsx <<'EOF'
import {
  AbsoluteFill,
  Audio,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Corte } from "./Corte";

const Cena = ({ texto, visual }) => {
  const frame = useCurrentFrame();
  const opacidade = interpolate(frame, [0, 12], [0, 1], {
    extrapolateRight: "clamp",
  });
  const subida = interpolate(frame, [0, 12], [40, 0], {
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill style={{ background: "linear-gradient(180deg, #0b2545, #13315c)" }}>
      {visual ? <Corte etapa={visual} /> : null}
      <AbsoluteFill
        style={{
          justifyContent: "flex-end",
          alignItems: "center",
          padding: 80,
          paddingBottom: 170,
        }}
      >
        <div
          style={{
            color: "white",
            fontSize: 70,
            fontWeight: 800,
            fontFamily: "sans-serif",
            textAlign: "center",
            opacity: opacidade,
            transform: `translateY(${subida}px)`,
            textShadow: "0 4px 20px rgba(0,0,0,0.8)",
          }}
        >
          {texto}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

export const Short = ({ roteiro }) => {
  const { fps } = useVideoConfig();
  let inicio = 0;
  return (
    <AbsoluteFill>
      {roteiro.cenas.map((c, i) => {
        const dur = c.segundos * fps;
        const el = (
          <Sequence key={i} from={inicio} durationInFrames={dur}>
            <Cena texto={c.texto} visual={c.visual} />
            {c.audio ? <Audio src={staticFile(c.audio)} /> : null}
          </Sequence>
        );
        inicio += dur;
        return el;
      })}
    </AbsoluteFill>
  );
};
EOF

# ---------- painel: opção de narração (se o painel estiver instalado) ----------
if [ -f painel/server.js ] && [ -f painel/index.html ]; then
cat > /tmp/patch.js <<'EOF_PATCH'
const fs = require("fs");

function aplicar(arq, marcador, trocas) {
  let t = fs.readFileSync(arq, "utf8");
  if (t.includes(marcador)) { console.log(arq + ": já atualizado"); return; }
  for (const [velho, novo] of trocas) {
    if (!t.includes(velho)) throw new Error("Trecho não encontrado em " + arq + ": " + velho.slice(0, 40));
    t = t.replace(velho, () => novo);
  }
  fs.writeFileSync(arq, t);
  console.log(arq + ": atualizado");
}

aplicar("painel/server.js", "narracao", [[
  String.raw`fs.writeFileSync(roteiroPath, JSON.stringify({ titulo, cenas }, null, 2));`,
  String.raw`fs.writeFileSync(roteiroPath, JSON.stringify({ titulo, narracao: b.narracao !== false, voz: String(b.voz || "pt-BR-FranciscaNeural"), cenas }, null, 2));`,
]]);

const cartao = String.raw`
  <div class="card">
    <h2>🔊 Narração <span class="opc">opcional</span></h2>
    <small>Uma voz lê o texto de cada cena e o vídeo se ajusta ao tempo da fala.</small>
    <label style="display:flex;gap:10px;align-items:center;font-weight:700;margin-bottom:10px">
      <input type="checkbox" id="narracao" checked style="width:auto"> Ativar narração
    </label>
    <select id="voz" style="width:100%;font:inherit;padding:12px;border:2px solid #e5e7eb;border-radius:14px">
      <option value="pt-BR-FranciscaNeural">👩 Francisca (feminina)</option>
      <option value="pt-BR-AntonioNeural">👨 Antônio (masculina)</option>
    </select>
  </div>
</main>`;

aplicar("painel/index.html", 'id="narracao"', [
  ["</main>", cartao],
  [
    String.raw`body: JSON.stringify({ titulo: $("tema").value, cenas }),`,
    String.raw`body: JSON.stringify({ titulo: $("tema").value, cenas, narracao: $("narracao").checked, voz: $("voz").value }),`,
  ],
  [
    String.raw`$("tema").value = e.roteiro.titulo || "";`,
    String.raw`$("tema").value = e.roteiro.titulo || "";
  $("narracao").checked = e.roteiro.narracao !== false;
  if (e.roteiro.voz) $("voz").value = e.roteiro.voz;`,
  ],
]);
EOF_PATCH
node /tmp/patch.js
fi

echo ""
echo "Pronto! Agora: git add . && git commit -m audio && git push"
