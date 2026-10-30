#!/data/data/com.termux/files/usr/bin/bash
# Uso (dentro da pasta do projeto): bash imagens.sh
set -e
mkdir -p public

# Copia as imagens cena1.jpg, cena2.jpg... da pasta Downloads
cp ~/storage/downloads/cena*.jpg public/ 2>/dev/null || true

# Atualiza o componente para mostrar a imagem da cena
cat > src/Short.jsx <<'EOF'
import {
  AbsoluteFill,
  Img,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const Cena = ({ texto, imagem }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const opacidade = interpolate(frame, [0, 12], [0, 1], {
    extrapolateRight: "clamp",
  });
  const subida = interpolate(frame, [0, 12], [40, 0], {
    extrapolateRight: "clamp",
  });
  const zoom = interpolate(frame, [0, durationInFrames], [1, 1.12]);
  return (
    <AbsoluteFill style={{ background: "#0b2545" }}>
      {imagem ? (
        <AbsoluteFill style={{ overflow: "hidden" }}>
          <Img
            src={staticFile(imagem)}
            style={{
              width: "100%",
              height: "100%",
              objectFit: "cover",
              transform: `scale(${zoom})`,
            }}
          />
        </AbsoluteFill>
      ) : null}
      <AbsoluteFill style={{ background: "rgba(0,0,0,0.45)" }} />
      <AbsoluteFill
        style={{
          justifyContent: "center",
          alignItems: "center",
          padding: 80,
        }}
      >
        <div
          style={{
            color: "white",
            fontSize: 80,
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
            <Cena texto={c.texto} imagem={c.imagem} />
          </Sequence>
        );
        inicio += dur;
        return el;
      })}
    </AbsoluteFill>
  );
};
EOF

# Liga cada cena a cenaN.jpg, só se o arquivo existir em public/
node -e '
const fs = require("fs");
const r = JSON.parse(fs.readFileSync("roteiro.json", "utf8"));
r.cenas.forEach((c, i) => {
  const f = "cena" + (i + 1) + ".jpg";
  if (fs.existsSync("public/" + f)) c.imagem = f;
  else delete c.imagem;
});
fs.writeFileSync("roteiro.json", JSON.stringify(r, null, 2));
console.log(r.cenas.map((c, i) => "cena " + (i + 1) + ": " + (c.imagem || "sem imagem")).join("\n"));
'

echo "Pronto! Agora: git add . && git commit -m imagens && git push"
