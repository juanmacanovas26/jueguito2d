# jueguito2d

MMORPG 2D de grind/farm con progresión emergente y construcción persistente.
Prototipo en Godot 4.7. El diseño vive en [`docs/`](docs/) — arrancá por
[`docs/GDD.md`](docs/GDD.md); [`docs/IDEAS2608.md`](docs/IDEAS2608.md) es el
documento largo de decisiones, con el estado de cada una.

## Poner a andar el proyecto en una máquina nueva

**1. Godot 4.7.1-stable.** La misma versión, no otra: `game/project.godot`
declara `config/features = ("4.7", "Forward Plus")` y el formato de las
escenas va atado a eso. Bajate el zip de Windows, que trae dos ejecutables:
el normal (para el editor) y el `_console` (el que usan los tests).

**2. Clonar y abrir.**

```bash
git clone https://github.com/juanmacanovas26/jueguito2d.git
cd jueguito2d
```

Abrí la carpeta `game/` desde el project manager de Godot. La primera vez
tarda unos minutos importando arte: `game/.godot/` está ignorado a propósito
(es caché, se regenera sola y nunca se commitea). El plugin de editor
`build_mode_editor` ya viene habilitado en `project.godot` — si Godot se
queja de un plugin faltante, es que `game/addons/` no llegó.

**3. Tests.**

```powershell
$env:GODOT = "C:\ruta\a\Godot_v4.7.1-stable_win64_console.exe"
powershell -File run_tests.ps1 -Verbose
```

Son 10 suites headless (systems, equipment, visuals, save, skills, zonebuild,
buildmode, structgrid, roadauto, paint). `run_tests.ps1` tiene una ruta por
defecto que es la de la máquina de escritorio; `$env:GODOT` la pisa. Poné esa
variable en las variables de entorno de Windows y te olvidás.

**4. Python 3.12 + Pillow**, solo si vas a tocar el pipeline de arte
(`game/tools/bake_road_autotile.py`, `art_pipeline/vfx/`, los scripts de la
skill `sprite-pipeline`).

```bash
pip install pillow
```

## Lo que NO está en el repo

El repo es público, así que hay dos cosas que se sincronizan por fuera:

- **`game/assets/_incoming/`** (~103 MB) — arte crudo y packs comprados, en
  staging antes de procesarse. No va al repo porque incluye packs de pago y
  publicarlos no corresponde. **Nada del proyecto lo referencia**: el juego
  corre sin esta carpeta, hace falta solo para generar assets nuevos. Se pasa
  por Drive o pendrive cuando la necesitás. Lo que sí está versionado es el
  resultado procesado, en `game/assets/world/`.
- **La config local de Claude Code** (`~/.claude/`): `settings.json`
  (permisos, modelo), `agents/`, y las skills personales. Las skills *del
  proyecto* sí viajan, en [`.claude/skills/`](.claude/skills/) — hoy
  `sprite-pipeline`. La memoria del proyecto vive en
  `~/.claude/projects/<ruta-del-proyecto>/memory/` y la clave es la ruta: si
  clonás en una carpeta con otro path, esa memoria arranca vacía.
  `.mcp.json` (supabase) sí está versionado, pero la autorización del MCP es
  por máquina y hay que hacerla de nuevo.

## Trabajar desde dos máquinas

`commit` + `push` antes de cerrar, `pull` al llegar. Lo único que no viaja es
caché (`game/.godot/`, `__pycache__/`), y está bien así: se regenera.

## Mapa del repo

| Carpeta | Qué hay |
|---|---|
| `game/` | El proyecto de Godot: escenas, scripts, assets, `tools/` con las suites de validación |
| `docs/` | GDD, documento de decisiones, arquitectura, combate, arte, engine |
| `art_pipeline/` | Scripts y plantillas para generar/cortar arte (LPC, VFX) |
| `lpc/` | Assets base de Liberated Pixel Cup |
| `Effects/`, `CharEditor/` | Packs de efectos y el editor de personajes de referencia |
| `game/tools/` | Herramientas de autor y suites de validación. `collider_editor.tscn` (F6) es con la que se le ponen colliders a los edificios — ver [`game/scenes/world/buildings/README.md`](game/scenes/world/buildings/README.md) |
| `run_tests.ps1` | Corre las 10 suites y devuelve código de salida distinto de cero si algo falla |
