# Freesla
Native dynamic notch app for macbook

## Qué hace

- **Isla sobre el notch**: se expande con un spring **al hacer clic** (el hover no la abre) y se contrae al sacar el
  ratón. Negra, y en el 25 % inferior se funde en Liquid Glass con refracción real de lo que hay detrás (ver
  [Refracción del cristal](#refracción-del-cristal)).
- **Música** (TIDAL o cualquier reproductor): barras animadas en el notch, carátula, progreso, pausa/siguiente/reiniciar.
- **Agente (Claude Code)**: logo con anillo del % de la ventana de 5 h; aviso al terminar cada tarea y cuando
  necesita tu atención (punto naranja, que desaparece al contestar); clic para ver uso de 5 h y semanal, tokens por
  día, tokens de la sesión y tok/s.
- **Estante**: suelta archivos en la isla (se expande sola al arrastrar) y sácalos arrastrando.
- **Icono en la barra de menús**: el logo de Freesla (imagen *template*, se tiñe sola en modo claro/oscuro). El menú
  permite actualizar el uso de Claude, vaciar el estante, activar/desactivar la refracción y salir.

## Requisitos y configuración

- macOS 26+ y Xcode con el **Metal Toolchain** (para compilar el shader):
  `xcodebuild -downloadComponent MetalToolchain`. App Sandbox desactivado (necesita leer `~/.claude`, el Llavero y
  lanzar `/usr/bin/perl`).
- **Firma**: hay que elegir un *Team* (vale un Apple ID gratuito) en Signing & Capabilities. Sin una identidad de
  firma estable, macOS trata cada compilación como una app nueva y vuelve a pedir el permiso de grabación de
  pantalla. El `DEVELOPMENT_TEAM` del proyecto es el del autor: cámbialo por el tuyo.
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

## Refracción del cristal

SwiftUI no puede leer los píxeles que hay detrás de una ventana, así que `BackdropCapture` hace una captura
puntual por segundo de la zona bajo el panel (ScreenCaptureKit, excluyendo la propia ventana), solo mientras la
isla está expandida. La imagen pasa por el shader `Island/LiquidGlass.metal` (lente en el borde, aberración
cromática y desenfoque).

- Requiere el permiso **Grabación de pantalla y audio del sistema** para Freesla. Se pide una sola vez; para volver
  a pedirlo, apaga y enciende **Refracción del cristal** en el menú.
- Sin permiso, o con el interruptor apagado, la isla usa el cristal normal del sistema (`glassEffect`).
- Los parámetros del efecto (desplazamiento, dispersión, desenfoque) están en `GlassSlab`, en `IslandView.swift`.

## Estructura

```
Freesla/
  App/        punto de entrada y AppDelegate (crea servicios y panel, detecta el ratón)
  Island/     vistas SwiftUI de la isla + shader LiquidGlass.metal
  Panel/      NotchPanel (ventana flotante sobre el notch) y utilidades de pantalla
  Services/   música, uso de Claude, eventos del agente, estante y captura del fondo
Design/       logos originales (blanco y negro)
```
