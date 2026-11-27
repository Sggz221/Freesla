# Freesla
Native dynamic notch app for macbook

## Qué hace

- **Isla sobre el notch**: se expande con un spring al pasar el ratón. Negra, y en el 25 % inferior se funde en Liquid Glass.
- **Música** (TIDAL o cualquier reproductor): barras animadas en el notch, carátula, progreso, pausa/siguiente/reiniciar.
- **Agente (Claude Code)**: logo con anillo del % de la ventana de 5 h; aviso al terminar cada tarea; clic para ver uso de 5 h y semanal, tokens por día, tokens de la sesión y tok/s.
- **Estante**: suelta archivos en la isla y sácalos arrastrando.

## Requisitos y configuración

- macOS 26+. App Sandbox desactivado (necesita leer `~/.claude`, el Llavero y lanzar `/usr/bin/perl`).
- **Música**: usa [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3), ya compilado en
  `Freesla/Resources/MediaRemoteAdapter/`. Para recompilarlo: `./scripts/build-mediaremote-adapter.sh`.
- **Uso de Claude**: lee el token de Claude Code del Llavero (`Claude Code-credentials`) y consulta el mismo
  endpoint que `/usage`. Hay que haber iniciado sesión en Claude Code.
- **Fin de tarea**: hooks en `~/.claude/settings.json` (`UserPromptSubmit`, `Stop`, `Notification`) que escriben el
  evento en `~/Library/Application Support/Freesla/agent-events/`:

  ```json
  { "type": "command", "command": "d=\"$HOME/Library/Application Support/Freesla/agent-events\"; mkdir -p \"$d\"; cat > \"$d/$(date +%s)-$$-$RANDOM.json\"" }
  ```
