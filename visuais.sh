#!/data/data/com.termux/files/usr/bin/bash
# Uso (dentro da pasta do projeto): bash visuais.sh
set -e

cat > src/Corte.jsx <<'EOF'
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";

// Linha de topo do aquífero (desce para a direita)
const A = (x) => 300 + 0.44 * (x - 40);

const estiloTexto = {
  fontFamily: "sans-serif",
  fontWeight: 800,
  fill: "white",
  paintOrder: "stroke",
  stroke: "#000",
  strokeWidth: 6,
};

export const Corte = ({ etapa }) => {
  const frame = useCurrentFrame();
  const fade = interpolate(frame, [0, 15], [0, 1], {
    extrapolateRight: "clamp",
  });

  // Chuva na zona de recarga
  const chuva = Array.from({ length: 9 }, (_, i) => {
    const x = 70 + i * 30;
    const g = A(x);
    const y = 100 + ((frame * 9 + i * 61) % (g - 100));
    return <circle key={i} cx={x} cy={y} r={7} fill="#8fd3ff" />;
  });

  // Água correndo dentro do aquífero
  const fluxo = Array.from({ length: 6 }, (_, i) => {
    const t = (frame * 0.012 + i / 6) % 1;
    const x = 60 + t * 960;
    return <circle key={i} cx={x} cy={A(x) + 55} r={9} fill="#bfeaff" />;
  });

  // Poço sendo perfurado e a água subindo
  const poco = interpolate(frame, [0, 20], [0, 1], {
    extrapolateRight: "clamp",
  });
  const agua = interpolate(frame, [20, 80], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const alturaPoco = 251 * poco;
  const alturaAgua = 251 * agua;

  const fonte =
    agua >= 1
      ? Array.from({ length: 5 }, (_, i) => {
          const fase = (frame * 0.05 + i / 5) % 1;
          const x = 860 + (i - 2) * 30 * fase;
          const y = 489 - 4 * 130 * fase * (1 - fase);
          return <circle key={i} cx={x} cy={y} r={7} fill="#4fc3f7" />;
        })
      : null;

  return (
    <AbsoluteFill style={{ opacity: fade }}>
      <svg
        viewBox="0 0 1080 960"
        style={{ position: "absolute", top: 120, left: 0, width: 1080, height: 960 }}
      >
        <defs>
          <pattern id="areia" width="16" height="16" patternUnits="userSpaceOnUse">
            <rect width="16" height="16" fill="#1f6fa3" />
            <circle cx="4" cy="4" r="2" fill="#6bb7e6" />
            <circle cx="12" cy="12" r="2" fill="#6bb7e6" />
          </pattern>
        </defs>

        {/* Rocha de base */}
        <polygon
          points="40,300 330,428 700,480 1040,500 1040,900 40,900"
          fill="#4a3b32"
        />
        {/* Camada pouco permeável (argila) */}
        <polygon points="330,428 700,480 1040,500 1040,740" fill="#8a6a4a" />
        {/* Aquífero */}
        <polygon points="40,300 1040,740 1040,850 40,410" fill="url(#areia)" />
        {/* Superfície com grama */}
        <polyline
          points="40,300 330,428 700,480 1040,500"
          fill="none"
          stroke="#5fb760"
          strokeWidth="12"
          strokeLinejoin="round"
        />

        {/* Casa */}
        <polygon points="925,430 975,390 1025,430" fill="#c0392b" />
        <rect x="935" y="430" width="80" height="70" fill="#f5e6c8" />
        <rect x="965" y="458" width="20" height="42" fill="#7a5a3a" />

        {/* Etapa 2: recarga */}
        {etapa >= 2 && chuva}
        {etapa >= 2 && (
          <text x="60" y="200" fontSize="38" {...{ style: estiloTexto }}>
            RECARGA
          </text>
        )}

        {/* Etapa 3: camadas e fluxo */}
        {etapa >= 3 && fluxo}
        {etapa >= 3 && (
          <text x="560" y="515" fontSize="28" style={estiloTexto}>
            POUCO PERMEÁVEL
          </text>
        )}
        {etapa >= 3 && (
          <text
            transform="translate(400 513) rotate(23.7)"
            y="10"
            fontSize="28"
            style={estiloTexto}
          >
            AQUÍFERO CONFINADO
          </text>
        )}

        {/* Etapa 4: poço */}
        {etapa >= 4 && (
          <>
            <rect x="852" y="489" width="16" height={alturaPoco} fill="#cfd8dc" />
            <rect
              x="856"
              y={740 - alturaAgua}
              width="8"
              height={alturaAgua}
              fill="#4fc3f7"
            />
            {fonte}
            <text x="836" y="440" fontSize="30" textAnchor="end" style={estiloTexto}>
              POÇO
            </text>
          </>
        )}
      </svg>
    </AbsoluteFill>
  );
};
EOF

cat > src/Short.jsx <<'EOF'
import {
  AbsoluteFill,
  Sequence,
  interpolate,
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
          </Sequence>
        );
        inicio += dur;
        return el;
      })}
    </AbsoluteFill>
  );
};
EOF

cat > roteiro.json <<'EOF'
{
  "titulo": "Poço Artesiano",
  "cenas": [
    { "texto": "Você sabe como funciona um poço artesiano?", "segundos": 4, "visual": 1 },
    { "texto": "A chuva infiltra na zona de recarga.", "segundos": 5, "visual": 2 },
    { "texto": "A água fica presa entre camadas pouco permeáveis.", "segundos": 5, "visual": 3 },
    { "texto": "A pressão faz a água subir sozinha pelo poço.", "segundos": 6, "visual": 4 }
  ]
}
EOF

echo "Pronto! Agora: git add . && git commit -m visuais && git push"
