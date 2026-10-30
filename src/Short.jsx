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
