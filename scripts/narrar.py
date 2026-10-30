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
