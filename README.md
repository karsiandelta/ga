# Oye Tío

App de Android que escucha con el móvil bloqueado. Dices **"oye tío, busca trenes Albacete Alicante…"**, busca en internet con la IA de Google (Gemini + búsqueda de Google) y, cuando sacas el móvil del bolsillo, se enciende la pantalla con la respuesta resumida, sin desbloquear.

## Cómo funciona

1. La palabra "oye tío" y tu frase se reconocen **en el propio móvil, sin internet** (modelo Vosk en español).
2. La pregunta va a Gemini con búsqueda de Google activada, que responde en formato corto: una línea por tren, con horas, duración, compañía y precio si lo encuentra.
3. El móvil vibra dos veces cuando la respuesta está lista.
4. El sensor de proximidad detecta cuándo lo sacas del bolsillo y entonces enciende la pantalla con la respuesta en grande.

## Conseguir el APK (sin ordenador)

1. Crea una cuenta en github.com y un repositorio nuevo (por ejemplo `oye-tio`).
2. Sube el contenido de esta carpeta (incluida la carpeta `.github`).
3. GitHub compila solo (pestaña **Actions**, tarda unos 5 minutos).
4. Ve a **Releases**, descarga `OyeTio.apk` en el móvil e instálalo (permite "instalar apps desconocidas" desde el navegador).

Cada vez que cambies algo y lo subas, sale una versión nueva que se instala encima.

## Primera configuración en el móvil

1. Saca una clave gratis en https://aistudio.google.com/apikey y pégala en la app.
2. Pulsa los botones 1 a 5 de "Para que funcione con el móvil bloqueado":
   - Micrófono y notificaciones: permitir.
   - Pantalla completa: activar (es lo que deja encender la pantalla con la respuesta).
   - Batería: "Sin restricciones".
   - Inicio automático: activarlo para Oye Tío.
   - Ajustes de la app → Notificaciones: activar "Pantalla de bloqueo" y "Ventanas flotantes".
3. Pulsa **Guardar y empezar a escuchar**. Aparece una notificación fija "Escuchando…".
4. Opcional en HyperOS: en Recientes, mantén pulsada la app y ponle el candado para que no la cierre.

## Límites a saber

- Los precios de tren cambian según el día y la ocupación; a veces solo saldrá "desde X €" o "precio no visto".
- El modelo de voz es pequeño: habla claro. Si no te pilla "oye tío", puedes cambiar la palabra en Ajustes (mejor dos palabras distintas y comunes).
- El plan gratuito de Gemini tiene un límite de consultas y Google puede usar lo que envías para mejorar sus productos. No le dictes datos privados.
- Si al sacar el móvil la pantalla no se enciende sola (algunos Xiaomi usan un sensor de proximidad "virtual" que se apaga con la pantalla), marca **Mostrar al instante**: se encenderá en cuanto esté lista la respuesta.
- Si sale "El modelo no existe", cambia el modelo en Ajustes por `gemini-2.5-flash` u otro de la lista de Google AI Studio.
