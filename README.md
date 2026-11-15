# Ahorcado Arcade

Ahorcado para dos jugadores por turnos, con categorías, premios diarios, monedas y tienda.

- `web/juego.html`: el juego entero (HTML, CSS y JS). Es la única fuente; se edita aquí.
- `tools/make_index.py`: genera `app/src/main/assets/index.html` con las fuentes incrustadas.
- `app/`: envoltorio Android (WebView) con anuncios con recompensa de AdMob y consentimiento RGPD.
- `admob.properties`: identificadores de AdMob. Ahora mismo son los de prueba de Google.

Cada subida a esta rama compila un AAB y un APK sin firmar y los publica como release.
La clave de firma no está en el repositorio.
