import {
  AbsoluteFill,
  Sequence,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const Cena = ({ texto }) => {
  const frame = useCurrentFrame();
  const opacidade = interpolate(frame, [0, 12], [0, 1], {
    extrapolateRight: "clamp",
  });
  const subida = interpolate(frame, [0, 12], [40, 0], {
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill
      style={{
        background: "linear-gradient(180deg, #0b2545, #13315c)",
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
        }}
      >
        {texto}
      </div>
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
            <Cena texto={c.texto} />
          </Sequence>
        );
        inicio += dur;
        return el;
      })}
    </AbsoluteFill>
  );
};
