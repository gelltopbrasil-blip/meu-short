import { Composition } from "remotion";
import { Short } from "./Short";
import roteiro from "../roteiro.json";

const FPS = 30;
const total = roteiro.cenas.reduce((s, c) => s + c.segundos * FPS, 0);

export const Root = () => (
  <Composition
    id="Short"
    component={Short}
    durationInFrames={total}
    fps={FPS}
    width={1080}
    height={1920}
    defaultProps={{ roteiro }}
  />
);
