#!/usr/bin/env python3
"""Genera app/src/main/assets/index.html a partir de web/juego.html, con las fuentes incrustadas (funciona sin conexión)."""
import base64, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
F = os.path.join(ROOT, "tools", "fonts")
FACES = [("Press Start 2P", 400, "press-start-2p-latin-400-normal.woff2"),
         ("VT323", 400, "vt323-latin-400-normal.woff2"),
         ("Rubik", 400, "rubik-latin-400-normal.woff2"),
         ("Rubik", 500, "rubik-latin-500-normal.woff2"),
         ("Rubik", 700, "rubik-latin-700-normal.woff2")]
def b64(name):
    with open(os.path.join(F, name), "rb") as f:
        return base64.b64encode(f.read()).decode()
css = "".join('@font-face{font-family:"%s";font-style:normal;font-weight:%d;font-display:swap;src:url(data:font/woff2;base64,%s) format("woff2")}\n' % (n, w, b64(p)) for n, w, p in FACES)
s = open(os.path.join(ROOT, "web", "juego.html"), encoding="utf-8").read()
s = re.sub(r'<link rel="stylesheet"[^>]*>\n', "", s, count=1)
s = s.replace('<meta name="claude:viewport-fit-sides" content="cover">\n', "")
s = s.replace("<style>\n", "<style>\n" + css + "html{-webkit-text-size-adjust:100%}body{margin:0}[hidden]{display:none!important}button{-webkit-tap-highlight-color:transparent;touch-action:manipulation}\n", 1)
head = '<!DOCTYPE html>\n<html lang="es">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no">\n'
i = s.index('<div id="app">')
out = head + s[:i] + "</head>\n<body>\n" + s[i:] + "</body>\n</html>\n"
assert "fonts.googleapis" not in out
dst = os.path.join(ROOT, "app", "src", "main", "assets")
os.makedirs(dst, exist_ok=True)
open(os.path.join(dst, "index.html"), "w", encoding="utf-8").write(out)
print("index.html", len(out) // 1024, "KB")
