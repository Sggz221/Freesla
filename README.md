# Freesla
Native dynamic notch app for macbook

## Qué hace

- **Isla sobre el notch**: se expande con un spring **al hacer clic** (el hover no la abre) y se contrae al sacar el
  ratón. Negra (#000000, como el notch físico), y en el 25 % inferior se funde en el cristal del sistema (`glassEffect`).
- **Tamaño del notch**: sin nada que mostrar, la isla contraída mide exactamente lo mismo que el notch (no asoma por
  los lados ni tapa el menú de las apps). Solo se ensancha con "orejas" cuando suena música o el agente está
  trabajando/terminando.
- **Monitores sin notch**: la hora del sistema (formato 12/24 h de macOS) va centrada en la isla.
- **Música** (TIDAL o cualquier reproductor): barras animadas en el notch, carátula, progreso, pausa/siguiente/reiniciar.
- **Agente (Claude Code)**: logo con anillo del % de la ventana de 5 h; aviso al terminar cada tarea y cuando
  necesita tu atención (punto naranja, que desaparece al contestar); clic para ver uso de 5 h y semanal, tokens por
  día, tokens de la sesión y tok/s.
- **Estante**: suelta archivos en la isla (se expande sola al arrastrar) y sácalos arrastrando.
- **Icono en la barra de menús**: el logo de Freesla (imagen *template*, se tiñe sola en modo claro/oscuro). El menú
  permite actualizar el uso de Claude, vaciar el estante, abrir Freesla al iniciar sesión y salir.
  Para que el inicio automático sea fiable, instala la app en `/Applications` y actívalo desde ahí.

## Requisitos y configuración

- macOS 26+. App Sandbox desactivado (necesita leer `~/.claude`, el Llavero y lanzar `/usr/bin/perl`).
- **Firma**: el `DEVELOPMENT_TEAM` del proyecto es el del autor; elige el tuyo en Signing & Capabilities
  (vale un Apple ID gratuito).
- **Música**: usa [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3), ya compilado en
  `Freesla/Resources/MediaRemoteAdapter/`. Para recompilarlo: `./scripts/build-mediaremote-adapter.sh`.
  Las posiciones de `seek` van en microsegundos y TIDAL ignora `seek 0` (por eso "reiniciar" pide 1 µs).
- **Uso de Claude**: lee el token de Claude Code del Llavero (`Claude Code-credentials`) y consulta el mismo
  endpoint que `/usage`. Hay que haber iniciado sesión en Claude Code.
- **Estado del agente**: hooks en `~/.claude/settings.json` (`UserPromptSubmit`, `Stop`, `Notification` y
  `PostToolUse`) que escriben el evento en `~/Library/Application Support/Freesla/agent-events/`. `PostToolUse`
  es lo que quita el aviso de "necesita tu atención" cuando contestas y el agente sigue trabajando. Reinicia la
  sesión de Claude Code tras añadirlos. Cada hook usa el mismo comando:

  ```json
  { "type": "command", "command": "d=\"$HOME/Library/Application Support/Freesla/agent-events\"; mkdir -p \"$d\"; cat > \"$d/$(date +%s)-$$-$RANDOM.json\"" }
  ```

## Estructura

```
Freesla/
  App/        punto de entrada y AppDelegate (crea servicios y panel, detecta el ratón)
  Island/     vistas SwiftUI de la isla
  Panel/      NotchPanel (ventana flotante sobre el notch) y utilidades de pantalla
  Services/   música, uso de Claude, eventos del agente, estante
Design/       logos originales (blanco y negro)
```
