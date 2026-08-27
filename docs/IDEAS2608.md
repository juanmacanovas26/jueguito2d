# Documento de Diseño — MMORPG 2D con progresión emergente y construcción persistente

> **Estado:** Documento vivo / borrador de trabajo
> **Última actualización:** 27 de agosto de 2026 — *rev. 8*
> **Propósito:** Consolidar las decisiones de diseño tomadas hasta ahora, explicar el *porqué* de cada una, dejar registrados los riesgos abiertos y las preguntas sin responder, para que cualquier iteración futura (propia o asistida por IA) tenga el contexto completo sin tener que reconstruirlo.
>
> **Novedades de rev. 8:** se agregó el camino de testing de red **Hamachi/Radmin/ZeroTier → VPS** antes de rentar infraestructura real (sección 2.14), y una primera sección de **estrategia de contenido/comunidad vía streaming de desarrollo** (sección 12). Esta última expone una tensión no resuelta con sección 2.12: el mercado objetivo decidido es angloparlante, pero el canal de comunidad más natural para el desarrollador es en español.
>
> **Novedades de rev. 7:** los claims fuera de ciudad dejan de estar limitados por cuenta y pasan a ser **exclusivos de clanes**, con una fundación deliberadamente difícil (gente + ítems especiales no comprables) (sección 5.4, sección 5.4.1). El housing urbano no cambia. Esto vuelve el anti-pay-to-win más robusto (ninguna cantidad de slots comprados acerca a un jugador solo a tener territorio) y reduce la cantidad total de claims en el mundo, lo que ayuda al presupuesto de RAM de sección 2.2.
>
> **Novedades de rev. 6:** comparativa honesta de mercados EE.UU. vs LATAM (sección 5.8) y **política de reinversión con orden de prioridades** (sección 5.9). Hallazgo principal: **abrir un shard con housing persistente es un compromiso casi permanente** — cerrarlo destruye lo que la gente construyó, así que el excedente va primero a fondo de reserva, no a un servidor nuevo.
>
> **Novedades de rev. 5:** estrategia de expansión regional definida — **lanzar con un shard en EE.UU., evaluar un shard LATAM más chico en el futuro** (sección 2.13). Consecuencia crítica: el esquema de datos debe tratar el `world_id` como concepto de primera clase **desde el día uno**, aunque solo exista un shard al lanzamiento.
>
> **Novedades de rev. 4:** se definió el **mercado objetivo: Estados Unidos / angloparlante**. Esto resuelve el último bloqueante de infraestructura, reactiva a Contabo como opción viable (sección 2.12) y abre un riesgo nuevo y específico: **el desarrollador no puede evaluar la sensación del combate desde su propia conexión** (sección 2.12.3).
>
> **Novedades de rev. 3:** investigación de hosting en Sudamérica (sección 2.11). Hallazgo principal: **São Paulo da mejor ping que Santiago desde Argentina** por razones de ruteo, y el sobrecosto respecto de Contabo es de 2×–4×. *Esta sección se conserva como referencia por si el mercado objetivo cambia.*
>
> **Novedades de rev. 2:** se definieron los dos bloqueantes principales — **combate de acción tipo Hades** y **existencia de PvP**. Esto reescribe el presupuesto de CPU (sección 2.9), agrega la latencia/región como factor crítico (sección 2.10), reclasifica el poder horizontal como obligatorio (sección 3.7) y baja la severidad del riesgo de azar en PvP (sección 4.8).
>
> **Novedades de rev. 2:** se definieron los dos bloqueantes principales — **combate de acción tipo Hades** y **existencia de PvP**. Esto reescribe el presupuesto de CPU (sección 2.9), agrega la latencia/región como factor crítico (sección 2.10), reclasifica el poder horizontal como obligatorio (sección 3.7) y baja la severidad del riesgo de azar en PvP (sección 4.8).

---

## 0. Cómo leer este documento

Cada sección grande sigue la misma estructura, a propósito:

1. **Qué es** — la descripción del sistema.
2. **Por qué así** — el razonamiento detrás de la decisión (esto es lo más importante para poder corregir después: si no sabés por qué se decidió algo, no sabés si cambiarlo rompe otra cosa).
3. **Riesgos / puntos débiles** — lo que puede salir mal, honestamente.
4. **Decisiones pendientes** — lo que todavía no está definido.

Al final hay un capítulo de **preguntas abiertas globales** y una **checklist de validación** para no avanzar en falso.

**Convención de estados:**

| Marca | Significado |
|---|---|
| ✅ **DECIDIDO** | Decisión tomada, con razón registrada. Cambiarla implica revisar dependencias. |
| 🟡 **TENTATIVO** | Dirección elegida pero sin cerrar detalles/números. |
| 🔴 **ABIERTO** | Sin decidir. Requiere definición o prueba. |

---

## 1. Visión general del proyecto

### 1.1 Qué es

Un **MMORPG 2D** con tres pilares que se refuerzan entre sí:

1. **Progresión emergente sin clases fijas.** El personaje no elige una clase de un menú; se convierte en algo por cómo se juega. Tres arquetipos base (Guerrero, Mágico, Rogue) son puntos de partida, no cajas cerradas.
2. **Construcción y propiedad persistente.** Housing dentro de las ciudades + sistema de construcción libre con claims fuera de ellas (referencia mecánica: Rust).
3. **Variabilidad tipo roguelite.** Aleatoriedad controlada en qué habilidades están disponibles para cada personaje, para que cada personaje se sienta una "run" distinta y para romper la convergencia al build meta.

### 1.2 La tesis central del diseño

> El jugador no debería poder mirar un video de YouTube titulado "LA MEJOR BUILD DE MAGO" y replicarla exactamente. Debería tener que **descubrir** su build, y esa build debería estar parcialmente condicionada por lo que el mundo le ofreció y por cómo jugó.

Todo lo demás está subordinado a esto.

### 1.3 Por qué así

El género tiene un problema conocido: por más opciones que se ofrezcan, la comunidad converge rápido a una build óptima y el resto del espacio de diseño queda muerto. Las tres palancas para combatir esto son: **progresión por uso** (el build es consecuencia de la conducta, no de una elección de menú), **escasez forzada** (no podés tener todo, hay que sacrificar), y **aleatoriedad de oferta** (no todas las opciones están disponibles siempre para todos).

### 1.4 Riesgos / puntos débiles

- Los tres pilares son, cada uno por separado, sistemas *caros de implementar y balancear*. Juntos, es un proyecto ambicioso. El riesgo principal del proyecto no es técnico, es de **alcance**.
- Los pilares 2 y 3 tienen tensión entre sí: la construcción persistente premia el compromiso de largo plazo con un personaje, mientras que la lógica roguelite empuja hacia la mentalidad de "run desechable". Esta tensión ya se resolvió (ver sección 5.4), pero cualquier cambio futuro debe revisarla de nuevo.

### 1.5 Definiciones estructurales

- ✅ **DECIDIDO — Combate de acción en tiempo real, tipo Hades.** Movimiento libre, dodge/dash como mecánica central, skills con timing y posicionamiento. La habilidad manual del jugador es un eje de poder tan importante como el build.
- ✅ **DECIDIDO — Hay PvP.** El alcance concreto (zonas, consecuencias, raideo de bases) se define en el entorno del proyecto.
- 🔴 **ABIERTO** — Escala objetivo de jugadores concurrentes al lanzamiento.

> **Nota:** los detalles técnicos de implementación de ambos sistemas se tratan dentro del entorno del proyecto, no en este documento. Acá solo se registran sus **consecuencias de diseño**, que son transversales a todo lo demás.

---

## 2. Infraestructura y servidor

### 2.1 Qué consume recursos en un MMORPG 2D

A diferencia de un juego 3D, el servidor **no renderiza nada**. Lo que pesa es:

| Recurso | Qué lo consume | Notas |
|---|---|---|
| **CPU** | El game loop: movimiento, combate, IA, pathfinding, ticks de simulación | Suele ser el cuello de botella real |
| **RAM** | Mapas, entidades, sesiones, inventarios, y **estructuras construidas persistentes** | En este proyecto crece con el tiempo, no solo con jugadores |
| **Red** | Posiciones y eventos (no video ni audio) | Bajo: ~1–10 KB/s por jugador según tick rate |
| **Disco / I/O** | Persistencia en base de datos, guardados del mundo | Puede pesar más que la lógica del juego si el guardado es sincrónico |

**Punto crítico sobre CPU:** los motores de MMORPG suelen correr el loop principal **single-thread por mundo o por zona**. Por lo tanto importa más la **velocidad de reloj por núcleo** que la cantidad de núcleos, salvo que se shardee el mapa en varios procesos/zonas.

### 2.2 El factor que cambia todo: construcción persistente

Este es el punto más importante de toda la sección de infraestructura.

**El consumo NO escala principalmente con jugadores concurrentes. Escala con la cantidad total de estructuras acumuladas en el mundo a lo largo del tiempo.**

Evidencia del género (servidores de Rust reales):

- Un mundo estándar con 50–100 jugadores necesita ~16 GB de RAM.
- Mapas grandes o servidores muy poblados **con un mes de bases acumuladas** superan los 24 GB.
- La memoria **crece a lo largo del ciclo de wipe** a medida que se acumulan entidades.
- Regla práctica del género: **dimensionar para el final del mes, no para el día uno.**

Por eso Rust hace wipes forzados mensuales: sin eso, el conteo de entidades explota y degrada el rendimiento sin importar cuánto hardware se le tire.

**Matiz favorable para un juego 2D:** no hay física/colisión 3D compleja (mallas, raycasting 3D), así que con el mismo número de entidades el costo de CPU será bastante menor que en Rust. Pero **el crecimiento de RAM y del tamaño de guardado sí aplica igual**, porque el problema no es gráfico: es cuántos objetos persistentes hay que simular y serializar.

### 2.3 Housing vs. construcción libre: costos muy distintos

| Sistema | Costo | Por qué |
|---|---|---|
| **Housing en ciudades** | **Bajo**, si es instanciado | Si cada casa es un interior que solo se carga cuando alguien entra (como una instancia/dungeon), casi no pesa sobre el mundo abierto |
| **Construcción libre + claims** | **Alto y creciente con el tiempo** | Estructuras persistentes en mapa abierto: siempre existen aunque nadie esté cerca, hay que guardarlas, indexarlas espacialmente, chequear decadencia |

✅ **DECIDIDO (implícito, conviene confirmar):** el housing urbano debería ser instanciado justamente por esta razón. 🔴 **ABIERTO:** confirmar si esto es compatible con la visión estética/social de las ciudades (una ciudad de puertas instanciadas se siente distinta a una ciudad con casas realmente ahí).

### 2.4 Optimizaciones de arquitectura — más importantes que el hardware

Estas cinco cosas van a ahorrar más dinero que cualquier upgrade de VPS:

1. **Sistema de decadencia (decay) / upkeep.** Si una construcción no tiene upkeep pagado o el claim está inactivo X días, se degrada y eventualmente se borra. **Sin esto, la RAM y el tiempo de guardado crecen indefinidamente hasta romper cualquier servidor.** No es una feature opcional: es la válvula de escape estructural del sistema.
2. **Simulación por proximidad.** No simular físicas/colisión de una estructura si no hay jugadores cerca. Mantenerla como dato estático en memoria/DB y "despertarla" solo cuando alguien entra en rango.
3. **Indexado espacial (grid o quadtree).** Para las consultas de "qué hay cerca de este jugador". Sin esto, cada tick se convierte en una búsqueda lineal sobre todas las estructuras del mundo — carísimo cuando el mundo crece.
4. **Guardado incremental y asíncrono.** Nunca un guardado completo del mundo que bloquee el loop principal cada X minutos.
5. **Límites de piezas por claim y por casa.** Acota el peor caso y hace predecible el consumo.

### 2.5 Dimensionamiento de hardware

Tabla base para un MMORPG 2D **sin** construcción pesada:

| CCU aprox. | CPU | RAM | Notas |
|---|---|---|---|
| 50–150 | 2 vCPU | 4 GB | De sobra para empezar/testear |
| 150–500 | 4 vCPU | 8 GB | Servidor chico-mediano "vivo" |
| 500–1500 | 6–8 vCPU | 16 GB | Conviene separar la BD del servidor de juego |
| 1500+ | Shardear (varios mapas/instancias en procesos distintos) | — | El escalado vertical solo ya no alcanza |

**Ajuste al alza por el sistema de construcción.** Dado sección 2.2, la recomendación real para este proyecto:

- **Lanzamiento y primeras semanas:** Contabo **Cloud VPS 20** (~6 vCPU / 12–18 GB RAM / ~150 GB NVMe) como piso razonable.
- **Meses 1–3, cuando la gente construya en serio:** planificar el salto a **Cloud VPS 30** (~8–10 vCPU / 24–36 GB RAM). Contabo permite upgrade sin migrar en la mayoría de los casos.
- **Si aparece lag por contención de CPU:** pasar a los planes **VDS** de Contabo (núcleos dedicados garantizados) en lugar de seguir subiendo de tier en Cloud VPS.

⚠️ **Advertencia importante sobre Contabo:** trabaja con vCPU compartidas y sobreventa de recursos (varias VMs comparten los mismos núcleos físicos). Para hosting web no se nota; para juegos en tiempo real que necesitan CPU constante y tick rate estable, hay reportes consistentes de contención en horas pico, que se traduce en lag y rubber-banding. Es el motivo por el cual la guía general del género desaconseja los planes "burstable" o de vCPU compartida para servidores de juego.

### 2.6 Riesgos / puntos débiles

- Todo el dimensionamiento de arriba es **estimación**. La eficiencia del código propio va a pesar más que la spec del servidor.
- El riesgo de infraestructura más grande no es "arrancar chico", es **no tener decay implementado desde el día uno** y descubrir a los dos meses que el mundo no entra en RAM.

### 2.7 Decisiones pendientes

- 🔴 Lenguaje/motor del servidor (condiciona fuertemente el rendimiento por núcleo y la estrategia de concurrencia).
- 🔴 Motor de base de datos y estrategia de persistencia.
- 🔴 ¿Un solo mundo o shards desde el inicio?
- 🔴 Parámetros concretos de decay: ¿cuántos días de inactividad? ¿Se degrada gradualmente o desaparece de golpe?
- 🔴 ¿Habrá wipes? (Rust los usa por necesidad técnica; en un MMORPG con housing y economía, un wipe es socialmente mucho más costoso. Si **no** hay wipes, el decay tiene que ser aún más agresivo.) **Esta es probablemente la decisión abierta más importante del documento.**

### 2.8 Acción recomendada antes de gastar en hardware

**Prueba de carga con bots.** Simular varios cientos de jugadores construyendo sin parar durante una hora y medir cómo crece la RAM y el tiempo de guardado. Esto dice más que cualquier tabla genérica, porque el costo real depende al 100% de cómo estén implementados el decay y la simulación por proximidad.

⚠️ **La prueba debe hacerse con el tick rate real del combate de acción** (ver sección 2.9), no con un tick lento. Medir con un tick bajo y después subirlo invalida todos los números.

---

### 2.9 Ajuste por combate de acción ✅ **NUEVO EN REV. 2**

Las tablas de sección 2.5 asumían un MMO 2D de ritmo pausado. **El combate tipo Hades cambia el presupuesto de CPU hacia arriba.**

**Por qué:**

| Factor | Efecto |
|---|---|
| **Tick rate alto** | Un combate con dodge y timing necesita actualizaciones frecuentes; cada tick recalcula posiciones, colisiones de hitbox y estados de todos los jugadores activos en la zona |
| **Servidor autoritativo** | Con PvP, el servidor tiene que validar movimiento y golpes (si confía en el cliente, hay cheats en la primera semana). Esa validación es CPU pura |
| **Más mensajes por jugador/segundo** | El tráfico sube respecto a la estimación de 1–10 KB/s de sección 2.1, aunque sigue siendo modesto comparado con un juego 3D |
| **Reconciliación / lag compensation** | Necesaria para que el combate se sienta justo; agrega trabajo por jugador |

**Qué NO cambia:** la conclusión central de sección 2.2 sigue en pie — el consumo de **RAM** sigue dominado por la acumulación de construcciones, no por el combate. Lo que sube es el **piso de CPU por jugador concurrente**.

**Implicancia práctica:** el número de CCU por servidor de las tablas de sección 2.5 hay que tratarlo como **optimista**. La recomendación de arrancar en Cloud VPS 20 y planificar el salto a VPS 30 se mantiene, pero con más urgencia, y la advertencia sobre vCPU compartidas de sección 2.5 pasa de "conviene tenerla en cuenta" a **casi bloqueante**: un juego de acción con tick rate estable es exactamente el peor caso para un vCPU sobrevendido. Las guías del género desaconsejan explícitamente los planes burstable o de CPU compartida para servidores de juego en tiempo real.

🔴 **ABIERTO:** tick rate objetivo. Es *el* número que define todo el presupuesto de CPU. Se define en el entorno del proyecto.

---

### 2.10 Latencia y región del servidor 🔴 **CRÍTICO — NUEVO EN REV. 2**

Con combate de acción y PvP, **el ping deja de ser un detalle de calidad y pasa a ser jugabilidad**. Un dodge con 200 ms de retardo no se siente injusto: se siente roto. En un tab-target eso es tolerable; acá no.

**Problema concreto con Contabo:** opera 9 regiones — Hub Europa (Lauterbourg), tres en EE.UU. (Nueva York, St. Louis, Seattle), Reino Unido (Portsmouth), y cuatro en Asia-Pacífico (Singapur, Tokio, Australia, India).

> ### ⚠️ **Contabo NO tiene datacenters en Sudamérica.**

Si la base de jugadores objetivo es latinoamericana, la mejor opción disponible sería US East (Nueva York) o US Central (St. Louis), lo que desde el Cono Sur implica una latencia considerable — aceptable para un MMO lento, **problemática para un combate tipo Hades con PvP**.

**Esto puede ser motivo suficiente para descartar Contabo**, aunque su relación specs/precio sea mejor que la de la competencia. La decisión pasa a ser:

| Opción | Trade-off |
|---|---|
| **Contabo US East/Central** | Mejores specs por el precio, peor ping para jugadores sudamericanos |
| **Proveedor con presencia en Sudamérica** (ej. São Paulo) | Menos specs por el mismo dinero, ping mucho mejor para la región |
| **Servidor en EE.UU. apuntando a público norteamericano** | Válido si la base objetivo no es local |

**Dato útil:** Contabo muestra la latencia real hacia cada región durante el proceso de contratación, así que se puede verificar el número concreto antes de comprometerse.

🔴 **DECISIÓN PENDIENTE — prioritaria:** definir **cuál es la base de jugadores objetivo geográficamente**. Esta decisión precede a la elección de proveedor, y con PvP de acción tiene más peso que las specs.

**Consideración adicional:** un MMO con PvP es un objetivo habitual de ataques DDoS. Verificar que el proveedor elegido incluya protección (Contabo la incluye en sus planes; otros la cobran aparte — ver sección 2.11).

---

### 2.11 Alternativas en Sudamérica ✅ **NUEVO EN REV. 3**

#### 2.11.1 Hallazgo contraintuitivo: São Paulo le gana a Santiago

La intuición geográfica falla acá. Chile está más cerca de Argentina que Brasil, pero **el ping desde Buenos Aires es peor hacia Santiago que hacia São Paulo.**

| Destino desde Buenos Aires | Ping típico reportado |
|---|---|
| **São Paulo** | 30–60 ms ✅ |
| **Santiago de Chile** | 80–120 ms ❌ |

**Por qué:** el problema es de **ruteo, no de distancia.** Buena parte del tráfico entre países sudamericanos no viaja directo: sale hacia **Miami y vuelve**. Hay casos documentados de tráfico Chile→Brasil que se rutea por Miami porque los operadores no tienen interconexión directa, haciendo imposible bajar de 100 ms.

**Conclusión operativa:** **São Paulo es el objetivo.** Es el hub real de la región (punto de intercambio IX.br) y donde está concentrada la oferta de hosting.

⚠️ **Advertencia sobre la variabilidad:** el ruteo en la región es inestable y depende del ISP de cada jugador. Hay reportes frecuentes de jugadores que de un día para otro pasan de 60 ms a 160 ms al mismo servidor por un cambio de ruteo de su proveedor. **Esto es un riesgo estructural del mercado latinoamericano que no se puede resolver desde el hosting** — conviene diseñar el netcode asumiendo latencia variable, no una latencia baja estable.

#### 2.11.2 La realidad de costos

> **Nada en Sudamérica se acerca a la relación precio/specs de Contabo.**

Contabo puede ser tan barato porque opera en Alemania y EE.UU., donde la infraestructura cuesta menos. Hospedar en Brasil es estructuralmente más caro (electricidad, impuestos, ancho de banda internacional).

**Presupuestar entre 2× y 4× el costo de Contabo por specs equivalentes.** Ese sobrecosto es, literalmente, el precio del ping — y con combate de acción y PvP no es opcional.

#### 2.11.3 Comparativa de proveedores

| Proveedor | Presencia | Características | Precio de referencia | Evaluación |
|---|---|---|---|---|
| **Vultr** ⭐ | São Paulo **y** Santiago | Línea High Frequency (Intel 3 GHz+, NVMe) y línea **Dedicated CPU** (VX1, cores AMD EPYC-Turin dedicados). Facturación por hora | HF 2 vCPU/4 GB ≈ USD 24/mes; HF 4 vCPU/8 GB ≈ USD 48/mes | **Mejor opción técnica.** El único internacional serio con cores dedicados en Brasil |
| **Hostinger** | São Paulo | Línea KVM, NVMe, cobro en reales, soporte en portugués | KVM1 (1 vCPU/4 GB/50 GB) ≈ R$28/mes en plan de 24 meses; KVM2 = 2 vCPU/8 GB | Barato, pero **vCPU compartida** — exactamente el riesgo que sección 2.9 marca como alto |
| **RazeHost** | São Paulo | Brasileño, **especializado en servidores de juego**. Dedicados, anti-DDoS incluido, conexión al IX.br | Variable | Vale evaluarlo: entienden el caso de uso |
| **Audaks / Magalu Cloud / HostDime / KingHost** | São Paulo (Tier III) | Proveedores brasileños generales, soporte en portugués, algunos ofrecen vCPU dedicada explícita | Variable | Opción de respaldo |

#### 2.11.4 Recomendación 🟡 **TENTATIVA**

**Vultr, región São Paulo, línea Dedicated CPU (no la compartida).**

Razones:

- **Cores dedicados garantizados** — crítico para el tick rate estable que exige el combate de acción (sección 2.9).
- NVMe (importante por el I/O de persistencia de construcciones, sección 2.1).
- **Facturación por hora**, lo que permite testear sin comprometerse a un contrato largo.
- Si en el futuro se quiere servir también a Chile o México, tienen regiones ahí.

**Tres advertencias sobre Vultr** que aparecen recurrentemente en las reseñas y que hay que sumar al presupuesto real:

1. **La protección DDoS es un extra de ~USD 10/mes por instancia**, no viene incluida como en Contabo. Para un MMO con PvP no es opcional.
2. **Los backups automáticos cuestan un 20% adicional** sobre el precio base de la instancia.
3. ⚠️ **Las instancias apagadas siguen facturando.** Hay que destruirlas para dejar de pagar — hay reportes de usuarios que descubrieron meses de cargos por esto. Cuidado durante la fase de pruebas.

**Sobre Hostinger:** el precio es tentador y el datacenter en São Paulo es real, pero (a) el precio promocional corresponde al plan de 24 meses y **sube 40–60% en la renovación**, y (b) sigue siendo vCPU compartida.

#### 2.11.5 Consideración fiscal desde Argentina

Pagar servicios en dólares desde Argentina tiene costo adicional por impuestos y percepciones. Los proveedores brasileños facturan en reales, lo que puede cambiar el cálculo real respecto de los precios de lista en USD.

🔴 **Verificar la normativa vigente al momento de contratar** — cambia con frecuencia y cualquier número escrito en este documento va a quedar desactualizado.

#### 2.11.6 Acción concreta antes de decidir

**Alquilar una instancia de Vultr en São Paulo por unas horas** (facturación por hora, costo de centavos) y **medir el ping real desde la ubicación propia y desde las de algunos testers**. Ese número decide todo lo demás y no se puede estimar de forma confiable desde una tabla.

> ⚠️ **Nota de rev. 4:** toda la sección 2.11 quedó **superada por la decisión de sección 2.12** (mercado objetivo = EE.UU.). Se conserva como referencia por si el mercado objetivo cambia o si en el futuro se abre un shard sudamericano.

---

### 2.12 Mercado objetivo y elección final de región ✅ **DECIDIDO — NUEVO EN REV. 4**

> ### 🇺🇸 **El juego apunta al público estadounidense / angloparlante.**

Esto resuelve el último bloqueante de infraestructura (sección 7.1) y cambia varias conclusiones anteriores.

#### 2.12.1 Consecuencias sobre el hosting

**Contabo vuelve a ser viable.** La objeción de sección 2.10 era que no tiene datacenters en Sudamérica — irrelevante si el público está en Norteamérica. Con eso vuelven a la mesa sus ventajas: mucha más spec por el mismo dinero (el orden de magnitud es ~6 vCPU / 12–18 GB por lo que un proveedor en São Paulo cobra por 2 vCPU / 4 GB), y el ahorro va directo al presupuesto de desarrollo.

**Qué región elegir dentro de EE.UU.:** Contabo ofrece US East (Nueva York), US Central (St. Louis) y US West (Seattle).

| Región | Cuándo conviene |
|---|---|
| **US Central (St. Louis)** ⭐ | **Recomendada por defecto.** Minimiza el peor caso costa a costa: nadie en EE.UU. continental queda demasiado lejos. Además es la región con la tarifa de ubicación más baja de Contabo |
| **US East (Nueva York)** | Si la comunidad se concentra en la costa este y/o se quiere buena latencia también hacia Europa |
| **US West (Seattle)** | Solo si la comunidad resulta ser mayoritariamente de la costa oeste |

Para un juego de acción con PvP y jugadores repartidos por todo el país, **US Central es la opción menos mala para el conjunto** — un servidor en Nueva York castiga fuerte a California y viceversa.

⚠️ **La advertencia de sección 2.9 sigue en pie y no la cancela nada de esto:** las vCPU de Contabo son compartidas y sobrevendidas. Para combate de acción con tick rate estable, **evaluar la línea VDS (núcleos dedicados) desde el inicio**, no como plan de contingencia. El ahorro respecto de un proveedor sudamericano da margen justamente para eso.

#### 2.12.2 Consecuencias fuera del hosting

Decidir el mercado no es solo una decisión técnica. Implica:

- **El juego se desarrolla en inglés como idioma primario.** No como traducción posterior: los nombres de skills, el lore, la UI y los textos de descubrimiento se escriben en inglés desde el inicio. Retrofitear esto es caro y se nota.
- **La comunidad (Discord, foros, redes) se construye en inglés.**
- **Los horarios de eventos, wipes y mantenimientos se planifican en husos horarios estadounidenses**, no locales.
- **El marketing apunta a canales angloparlantes** (Reddit, Steam, YouTube en inglés).
- 🔴 **ABIERTO:** definir si se soporta español como idioma secundario y en qué momento.

#### 2.12.3 🔴 Riesgo nuevo y específico: el desarrollador está lejos del servidor

> **El desarrollador (en Argentina) va a experimentar el juego con peor latencia que su público objetivo.**

Con el servidor en EE.UU. Central, el ping desde Argentina será considerablemente mayor que el de un jugador estadounidense promedio. Esto tiene una consecuencia concreta y peligrosa:

**No se puede confiar en la propia sensación para calibrar el netcode, el timing del dodge, las ventanas de i-frames ni el feel del combate.** Si se ajusta el combate hasta que "se sienta bien" desde Argentina, es probable que quede mal calibrado para quien juega con 30 ms — por ejemplo, ventanas de dodge demasiado generosas que hacen el combate trivial para el público real.

**Mitigaciones:**

1. **Conseguir testers en EE.UU. desde temprano**, no al final. Su feedback sobre el *feel* del combate vale más que el propio.
2. **Instrumentar el juego para medir latencia** y registrar el ping de cada tester junto con su feedback, para poder separar "esto se siente mal" de "esto se siente mal *a 180 ms*".
3. **Probar con latencia simulada** en el entorno local (herramientas de traffic shaping que agregan retardo artificial) para poder experimentar cómo se siente el juego a 30 ms sin estar físicamente ahí.

Este riesgo es fácil de subestimar y difícil de detectar tarde: se manifiesta como "el combate se siente raro" en las reseñas, sin causa evidente.

---

### 2.13 Estrategia de expansión regional (shards) 🟡 **TENTATIVO — NUEVO EN REV. 5**

**El plan:** lanzar con **un solo shard en EE.UU.** y evaluar más adelante un **shard LATAM más chico**, si la demanda lo justifica.

La secuencia es correcta: no tiene sentido pagar dos servidores para una comunidad que todavía no existe. Pero hay tres implicancias que conviene resolver ahora, no después.

#### 2.13.1 ⚠️ La preparación técnica es AHORA, aunque el segundo shard sea dentro de dos años

> **El esquema de base de datos debe tratar el `world_id` (o `shard_id`) como concepto de primera clase desde el día uno.**

Cada personaje, cada casa, cada claim, cada estructura, cada registro de economía debe estar asociado a un mundo desde la primera línea de código, aunque ese campo valga siempre `1` durante los primeros dos años.

**Por qué es innegociable:** agregar un shard a un sistema que asumió "hay un solo mundo" implica migrar toda la base de datos en producción, con jugadores que tienen propiedad persistente y economía activa. Es de las migraciones más dolorosas que existen. Poner el campo desde el inicio cuesta prácticamente nada.

Lo mismo aplica a la lógica de guardado, al indexado espacial (sección 2.4) y a cualquier consulta de "qué hay cerca": todas deben estar scopeadas por mundo desde el principio.

#### 2.13.2 🔴 El riesgo real no es técnico: es fragmentar una comunidad chica

**El peor enemigo de un MMO es un servidor vacío.** Un shard con poca gente se siente muerto, y la sensación de mundo vivo es justamente lo que sostiene a un MMORPG. Partir una comunidad pequeña en dos mitades produce **dos servidores que se sienten muertos** en lugar de uno que se siente vivo.

**Regla para decidir cuándo abrir el shard LATAM:**

> Se abre un segundo shard cuando el primero **ya tiene problemas de capacidad o de saturación de terreno**, no cuando hay jugadores latinoamericanos pidiéndolo.

Un puñado de jugadores latinoamericanos con ping alto pero un mundo poblado la pasa mejor que esos mismos jugadores solos en un mundo vacío con buen ping.

**Alternativa a considerar antes de abrir un shard:** si aparece demanda latinoamericana temprana, evaluar mejoras de netcode (interpolación, lag compensation más agresiva) o simplemente comunicar con honestidad que el servidor está en EE.UU. Muchos jugadores latinoamericanos ya juegan MMOs en servidores norteamericanos y lo aceptan; lo que no aceptan es un mundo vacío.

#### 2.13.3 Consecuencias de diseño de tener shards separados

Con propiedad persistente, los shards **no son copias intercambiables: son mundos distintos.** Hay que decidir explícitamente:

| Pregunta | Estado | Nota |
|---|---|---|
| ¿El límite de housing urbano por cuenta (sección 5.4) es global o por shard? | 🔴 ABIERTO | **Recomendado: por cuenta *y* por shard.** Si fuera global, un jugador con personajes en ambos mundos no podría tener casa en los dos, lo cual no tiene sentido y se sentiría arbitrario |
| ¿Un clan existe en un solo shard o puede operar en varios? (rev. 7, sección 5.4.1) | 🔴 ABIERTO | Con economías separadas por shard (fila siguiente), lo más simple es que un clan —y sus claims— pertenezcan a un único mundo |
| ¿Los personajes pueden transferirse entre shards? | 🔴 ABIERTO | El estándar del género es la transferencia paga. **Pero la propiedad NO puede transferirse** — la casa y el claim quedan en el mundo donde se fundaron |
| ¿La economía es separada por shard? | 🟡 Sí, necesariamente | Dos mundos con construcción y recursos persistentes no pueden compartir mercado sin romper el balance de ambos |
| ¿Los slots de personaje son por cuenta global? | 🟡 Sí | Los slots son de la cuenta; en qué mundo se crea cada personaje lo elige el jugador |
| ¿La meta-progresión cosmética (sección 5.2) es global? | 🟡 Sí | Al ser puramente cosmética, no hay riesgo de ventaja cruzada entre mundos |

#### 2.13.4 Dimensionamiento del shard LATAM

Cuando llegue el momento, el shard LATAM **puede ser más chico** — no necesita el mismo hardware que el principal. Referencia: São Paulo, con las opciones y el sobrecosto ya analizados en sección 2.11 (que por eso se conservó en este documento).

**Consideración de costos:** un segundo shard no duplica el costo de infraestructura solamente. También duplica el trabajo de operación: mantenimientos, backups, monitoreo, moderación, y eventos comunitarios en dos husos horarios distintos. Para un proyecto chico, **ese costo operativo suele pesar más que el del servidor**.

---

### 2.14 Camino de testing antes del VPS: Hamachi/Radmin/ZeroTier ✅ **NUEVO EN REV. 8**

**Estado del código a la fecha de esta revisión:** no existe ninguna capa de networking implementada todavía (sin `MultiplayerAPI`/`ENetMultiplayerPeer` ni servidor/cliente). El proyecto es hoy un juego local de un jugador. Todo lo que sigue es el plan para cuando esa capa se construya.

**El plan:** antes de pagar cualquier VPS, probar el multiplayer con amigos usando una VPN de LAN virtual (Hamachi, Radmin VPN o ZeroTier) apuntando al servidor corriendo en la propia PC.

**Por qué funciona:** con arquitectura server-authoritative sobre ENet, el cliente solo necesita una IP:puerto a la cual conectarse. Una VPN de este tipo crea una red virtual "de confianza" entre las PCs de los testers, evitando tener que abrir puertos en el router de casa (NAT/port forwarding) para gente fuera de la LAN física. Es el mismo patrón que se usaba para LAN de Minecraft/juegos viejos sin matchmaking.

**Por qué el salto a VPS después es fácil (si se hace bien desde el inicio):** el código de red no distingue entre "servidor en mi PC vía Hamachi" y "servidor en un VPS" — en ambos casos es una IP:puerto. Migrar es trivial **solo si**:

1. La dirección del servidor es **configurable** en el cliente (input/config/env var), nunca hardcodeada.
2. El servidor puede correr **headless** (`--headless`, sin ventana/audio) — necesario en un VPS y bueno para probarlo ya en local. Requiere que la lógica de servidor esté separada de nodos que dependan del árbol visual (UI, cámara).
3. Se probó la build headless en **Linux** al menos una vez antes de necesitarla con urgencia (la mayoría de los VPS son Linux).
4. El manejo de puertos/firewall se revisa al migrar: en VPN no hace falta abrir nada; en VPS con IP pública sí hay que abrir el puerto UDP de ENet en el firewall del proveedor.

**Diferencia de riesgo entre el test con amigos y una futura apertura pública:** con amigos de confianza en una VPN privada, es tolerable ser laxo con la validación de acciones del cliente durante las primeras pruebas. Esa relajación **no debe llegar a un VPS con público real** — ahí aplica sin excepción el servidor autoritativo ya definido como bloqueante de diseño (sección 3.7, riesgo de cheating en sección 8).

**Relación con los bloqueantes de sección 7.1:** este camino de testing no reemplaza ni adelanta las decisiones de motor/lenguaje del servidor, tick rate, ni Cloud VPS vs. VDS. Es el entorno donde esas decisiones se prueban baratas (con Hamachi de por medio) antes de comprometer dinero en infraestructura real.

#### 2.14.1 Riesgos / puntos débiles

- Si el código de red asume implícitamente "somos todos LAN" (por ejemplo, sin separar validación cliente/servidor porque "total son mis amigos"), ese supuesto se cuela fácil hasta producción si no se revisa explícitamente antes de abrir el juego a desconocidos.
- Hamachi específicamente tiene reputación de ser menos estable que alternativas más nuevas (Radmin VPN, ZeroTier); vale la pena probar más de una antes de comprometerse a una para todas las sesiones de testeo.

#### 2.14.2 Decisiones pendientes

- 🔴 Con qué VPN de testing se arranca (Hamachi / Radmin / ZeroTier).
- 🔴 En qué punto del desarrollo de la capa de networking se hace la primera prueba headless en Linux (conviene no dejarlo para el final).

---

## 3. Sistema de progresión: builds emergentes

### 3.1 Qué es

Un sistema sin clases fijas donde el personaje se define por lo que hace, no por lo que eligió al crearse.

**Arquetipos de partida (3):**

| Arquetipo | Base | Destinos posibles (ejemplos, no exhaustivos) |
|---|---|---|
| **Guerrero** | Melee pesado | Tanque, DPS a pecho descubierto, Bruiser, Berserker |
| **Mágico** | Casteo | Mago clásico, Brujo, Nigromante, Druida, Clérigo (híbrido con melee), Sanador puro |
| **Rogue** | Agilidad/sigilo | Arquero, Asesino, Domador de criaturas (híbrido druida/arquero) |

El arquetipo determina: stats iniciales, acceso más rápido/barato a ciertas ramas, y quizás alguna skill exclusiva de arranque. **No determina un techo.**

### 3.2 Componente 1: progresión por uso ✅ **DECIDIDO**

Las skills suben según cuánto se usan, no por asignación de puntos al subir de nivel.

- Pegar mucho con espada a dos manos sube "Espadas Pesadas".
- Castear mucho fuego sube "Piromancia".
- Bloquear mucho sube "Escudo"; esquivar mucho sube movilidad.

**Efecto buscado:** dos Guerreros terminan distintos según su conducta real en combate, sin que ninguno haya "elegido" ser distinto.

**Referencia del género:** Ultima Online.

### 3.3 Componente 2: cap total de skill ✅ **DECIDIDO**

Existe un **límite total de puntos de skill activos** por personaje. Para subir una skill nueva estando en el tope, hay que bajar otra.

**Por qué es indispensable:** sin cap, la progresión por uso degenera en "con suficiente tiempo, todos son dioses de todo", y el juego converge a un único build máximo. El cap **fuerza especialización sin que el diseñador tenga que diseñarla a mano** — el jugador la elige con sus acciones y con lo que decide sacrificar.

**Referencia del género:** el límite de ~700 puntos de Ultima Online.

🔴 **ABIERTO:** el número concreto del cap, y si el cap es fijo o crece levemente con el progreso.

### 3.4 Componente 3: red de skills, no árbol de clases ✅ **DECIDIDO**

En lugar de compartimentos cerrados por clase, una **red (web)** donde cualquier personaje puede, en teoría, aprender cualquier skill — solo que le cuesta más caro/lento si no pertenece a su arquetipo.

Así emergen los híbridos de forma natural:

- Guerrero que invierte de a poco en magia curativa → **Clérigo**.
- Mágico que suma invocación de criaturas + arco → **Druida / Domador**.
- Rogue que suma supervivencia + vínculo con bestias → **Domador de criaturas**.

**La regla no es "elegís ser Clérigo". Es "jugás de cierta forma y el sistema reconoce el patrón".**

### 3.5 Componente 4: descubrimiento — skills que "nacen" ✅ **DECIDIDO**

No todas las skills están disponibles desde un menú. Vías de obtención:

1. **Tomos / pergaminos raros** dropeados en el mundo (ej.: cierta rama de nigromancia solo la enseña un libro que dropea un boss específico).
2. **NPCs maestros condicionales** que solo enseñan si se cumple algo: reputación, quest, o directamente el build actual (un maestro de asesinos no le enseña a alguien vestido de tanque con maza).
3. **"Despertar" por uso combinado:** si se combinan ciertas skills lo suficiente (ej.: mucho daño físico + mucho fuego), se desbloquea una skill híbrida que antes no existía en la lista ("Filo Incandescente"). El sistema **detecta un patrón de conducta y regala el descubrimiento**.

**Por qué importa tanto:** hace que el diseñador **no tenga que enumerar cada build posible de antemano**. La combinatoria genera builds imprevistas, y la comunidad las descubre y comparte — lo que produce contenido meta orgánico y cambiante en lugar de una wiki estática.

### 3.6 Componente 5: títulos / identidades emergentes 🟡 **TENTATIVO**

Para que el jugador *sienta* que se convirtió en algo, el sistema le reconoce un título cuando su combinación de skills cruza ciertos umbrales:

- Alta Defensa + Provocación + Resistencia → **Tanque**
- Armadura ligera baja + Crítico alto + Berserker → **DPS a pecho descubierto**
- Curación + armas cuerpo a cuerpo → **Clérigo**

**Clave:** son **etiquetas que emergen del build real**, no compartimentos que restringen. Dan sabor de rol sin fijar 15 clases.

🔴 **ABIERTO:** ¿los títulos son puramente cosméticos/narrativos, o llevan un pasivo mecánico menor asociado? (Si llevan pasivo, se convierten en objetivo de optimización y pueden reintroducir el problema del meta por la puerta de atrás.)

### 3.7 Cómo se combate la convergencia al meta

Este es el riesgo real: **la comunidad siempre encuentra la combinación numéricamente más fuerte y la copia**, incluso en sistemas con miles de nodos (pasa en Path of Exile). Contramedidas:

1. **Poder horizontal, no vertical.** 🔴 **OBLIGATORIO — reclasificado en rev. 2.** Las skills deben ser fuertes en *situaciones distintas*, no simplemente "número más grande". Un Bruiser gana el 1v1 pero sufre contra grupos que kitean; un Nigromante DPS es fuerte contra un objetivo único pero flojo en AoE. Así el meta **depende del contexto** y no hay ganador universal.

   > **Por qué subió de "recomendable" a "obligatorio":** con PvP confirmado y builds asimétricas por diseño, si una skill es estrictamente mejor que otra en todo contexto, **el PvP se rompe rápido** y toda la premisa de variedad se cae — la comunidad converge a la build dominante y el resto de la red de skills queda decorativa. Sin PvP esto sería un problema de sabor; con PvP es un problema estructural.
2. **Costo real de especializarse** (el cap de sección 3.3). Si todos pueden llegar a todo, todos convergen. Si hay que sacrificar, la gente elige distinto según lo que valora.
3. **El gear como eje adicional de diferenciación.** El equipo modifica *cómo se comporta* una skill (una espada de fuego convierte tu estocada en algo elemental). Así, dos builds idénticas en skills se juegan distinto según el loot conseguido.
4. **No ocultar información para evitar el meta — no funciona.** La comunidad hace wikis en días. La estrategia correcta es diseñar para que existan *varios* builds genuinamente viables, no para esconder cuál es el mejor.

### 3.8 Riesgos / puntos débiles

- **Progresión por uso invita al grindeo degenerado:** gente pegándole a un muñeco de práctica, o auto-clickers subiendo skills sin jugar. Necesita mitigación explícita (ganancia solo contra enemigos de nivel apropiado, rendimientos decrecientes, requisitos de contexto).
- **Descubribilidad:** si el sistema es demasiado opaco, el jugador nuevo se siente perdido en lugar de intrigado. Hay que comunicar el progreso aunque no se revelen todos los destinos.
- **El cap puede sentirse punitivo** si bajar una skill se percibe como "perder" progreso trabajado. Diseñar la UX de esto con cuidado (¿la skill baja o queda "dormida" y recuperable?).
- **Balancear una red abierta es exponencialmente más difícil** que balancear 8 clases cerradas. Este es el costo real de todo el enfoque, y hay que aceptarlo conscientemente.

### 3.9 Decisiones pendientes

- 🔴 Cuántas skills tendrá la red en total (esto define el alcance de trabajo y la dificultad de balance).
- 🔴 Curva de progresión por uso: ¿lineal? ¿logarítmica? ¿con rendimientos decrecientes por sesión?
- 🔴 Mitigación anti-grindeo pasivo.
- 🔴 Si bajar una skill al llegar al cap es reversible o no.

---

## 4. Capa roguelite: aleatoriedad controlada

### 4.1 Qué es

Una capa de azar acotado sobre la red de skills, para que crear un personaje se sienta como "a ver qué me toca" en lugar de "voy directo a la build óptima del video".

**Referencia del género:** Hades, Slay the Spire, Risk of Rain 2.

### 4.2 La diferencia crítica con un roguelite real

⚠️ **Esta es la advertencia más importante de la sección.**

En un roguelite, una run dura 20–40 minutos y perderla no cuesta nada. En este juego, un personaje tiene **housing, gremio, relaciones sociales, economía** — es una inversión de semanas.

**Por lo tanto: la aleatoriedad debe generar *sabor*, nunca *inviabilidad*.** Todo el subsistema de abajo está diseñado alrededor de esa regla.

### 4.3 Componente 1: rolls continuos, NO pool fijado al nacer ✅ **DECIDIDO** *(corrección importante)*

**Diseño descartado:** samplear un "pool de skills" aleatorio una única vez al crear el personaje, dejándolo atado de por vida a lo que le tocó.

**Por qué se descartó:** un mal roll de nacimiento genera un incentivo directo a **abandonar el personaje y crear otro** — exactamente lo que no se quiere en un juego con propiedad persistente y vínculos sociales.

**Diseño adoptado:** cada momento de descubrimiento hace **su propio roll independiente**, en el momento en que ocurre (subida de nivel, drop, combinación de uso, boss derrotado), ponderado por el build actual.

**Efecto:** no existe "mal roll de nacimiento" del que escapar, porque el personaje sigue recibiendo oportunidades nuevas durante toda su vida. Si no gustó lo ofrecido esta vez, la próxima puede ser mejor — **sin necesitar un personaje nuevo.** Esto elimina la mayor parte del incentivo al alt-spam.

### 4.4 Componente 2: elección "1 de 3" ✅ **DECIDIDO**

Cuando se dispara un descubrimiento, en lugar de asignar una skill automáticamente, se ofrecen **3 opciones** y el jugador elige una.

Por qué:

- **Mantiene agencia real** — no es azar pasivo.
- **Permite ponderar por sinergia**: si el jugador viene usando fuego, sube la probabilidad de ofrecerle piromancia o algo que sinergice, en vez de azar uniforme.
- Produce el momento característico de Hades: *"justo ahora me ofrecieron la pieza que le faltaba a mi build"*.

### 4.5 Componente 3: núcleo garantizado + capa distintiva ✅ **DECIDIDO**

| Categoría | Contenido | Aleatorio |
|---|---|---|
| **Núcleo garantizado** | 3–4 skills básicas del arquetipo (golpe básico, bloqueo, movilidad) | ❌ Siempre disponibles |
| **Distintivas** | Todo lo que define el sabor único (Bruiser vs Tanque vs Berserker) | ✅ Sale del roll |

**Garantiza que el personaje sea jugable pase lo que pase.** Nadie queda sin poder jugar; lo que varía es qué tan especial o raro es lo que le tocó.

### 4.6 Componente 4: wildcards raros 🟡 **TENTATIVO**

Con baja probabilidad, un drop de mundo o un evento puede ofrecer una skill **fuera de toda la lógica de ponderación normal** — el equivalente a un legendario inesperado en Noita o Risk of Rain 2.

**Para qué sirve:** genera las historias de *"encontré un tomo de nigromancia rarísimo en una mazmorra y ahí arrancó mi build de nigromante"*. Es el motor de narrativa emergente y de conversación en la comunidad.

### 4.7 Componente 5: válvulas de escape ✅ **DECIDIDO**

Porque en un MMO un mal resultado duele mucho más que en un roguelite:

1. **Reroll limitado.** Un ítem/moneda rara que permite re-tirar una rama específica. ⚠️ **Debe obtenerse por logro/juego, NO por cash shop** — si se vende, es pay-to-win directo sobre el sistema de progresión.
2. **Ventana de gracia temprana.** En los primeros niveles, permitir 1–2 rerolls completos gratis, antes de que la inversión sea alta. Así un mal resultado solo duele si el jugador lo dejó pasar sabiendo que era malo.
3. **Nunca randomizar la viabilidad básica** — ya cubierto por el núcleo garantizado (sección 4.5), pero vale como regla de diseño transversal.

### 4.8 Riesgos / puntos débiles

- **Riesgo de percepción de injusticia en PvP:** 🟢 **MITIGADO PARCIALMENTE EN REV. 2.** La preocupación original era que dos jugadores con el mismo tiempo invertido tuvieran poder distinto por azar, volviendo el PvP arbitrario.

  **El combate de acción tipo Hades reduce mucho este riesgo.** En un sistema donde el posicionamiento, el timing del dodge y la lectura del oponente deciden peleas, **la habilidad manual del jugador absorbe buena parte de la asimetría de build**. Un build peor, bien manejado, sigue siendo competitivo. En un tab-target, el build sería casi todo el resultado y el azar sería mucho más difícil de defender.

  **Lo que queda del riesgo:** el azar sigue sin poder producir builds *inviables* (por eso el núcleo garantizado de sección 4.5 es innegociable), y una diferencia de poder muy grande igual sería frustrante por más skill que tenga el jugador. La regla sigue siendo: **el azar genera sabor, la habilidad decide peleas.**
- **La ponderación por sinergia puede volverse predecible** y anular la sensación de azar. Necesita algo de ruido genuino.
- Los rerolls, si son demasiado accesibles, matan todo el sistema (todos rerollean hasta el build óptimo → vuelve el meta). Si son demasiado escasos, generan frustración. **Es un número delicado que solo se calibra con jugadores reales.**

### 4.9 Decisiones pendientes

- 🔴 Frecuencia de los momentos de descubrimiento.
- 🔴 Cuánto pesa la sinergia vs. el azar puro en la ponderación de las 3 opciones.
- 🔴 Rareza y fuente exacta de los ítems de reroll.
- 🔴 Cómo interactúa esta capa con el PvP (bloqueado hasta definir PvP).

---

## 5. Personajes, cuentas y economía de slots

### 5.1 Meta-progresión entre personajes: qué se descartó y por qué ✅ **DECIDIDO** *(corrección importante)*

**Diseño descartado:** que descubrir skills raras con un personaje aumente la probabilidad de que aparezcan en los futuros personajes de la cuenta (modelo blueprints de Dead Cells / espejo de Hades).

**Por qué se descartó:** en un roguelite eso es sano porque la unidad "run" es descartable por diseño. En este MMO, la unidad "personaje" carga housing, gremio, vínculos sociales y economía. Dar una razón **mecánica** para tirar un personaje y hacer otro incentiva exactamente lo contrario a lo buscado: gente creando personajes descartables para farmear mejores probabilidades, en vez de comprometerse con el que ya tiene.

Además es un problema de infraestructura: cada personaje nuevo con casa, storage e inventario es carga real y permanente en la base de datos (ver sección 2).

### 5.2 Qué SÍ puede ser meta-progresión de cuenta ✅ **DECIDIDO**

Se conserva la capa de "la cuenta tiene historia", pero **sin poder mecánico**:

- Códice / bestiario de skills vistas (lore, no probabilidad).
- Títulos y cosméticos de legado.
- Conveniencia: slots adicionales, acceso a mercado o banco compartido entre personajes.

**Regla:** meta-progresión de cuenta = cosmético y conveniencia. Nunca ventaja mecánica.

### 5.3 Slots de personaje 🟡 **TENTATIVO**

- **2 slots gratis.**
- Ampliable **hasta 5** mediante compra.
- Precio inicial contemplado: **~USD 5 por slot**.

**Comparación de mercado:** WoW cobra ~USD 15 por slot; Guild Wars 2 históricamente ~USD 10 (800 gemas). USD 5 está en la punta baja del rango — coherente con bajar la barrera de entrada para un juego nuevo/indie.

⚠️ **Nota estratégica:** es más fácil **subir** precios después de generar tracción que bajarlos sin devaluar el producto. Conviene dejar margen.

**Alternativa sugerida — precio escalonado:**

| Slot | Precio sugerido |
|---|---|
| 3.º | USD 5 |
| 4.º | USD 7 |
| 5.º | USD 10 |

Mantiene la accesibilidad para quien solo quiere probar otro arquetipo, desalienta el acaparamiento, y captura más valor de quien realmente quiere varios personajes.

**Consideración de costos:** cada slot activo implica potencialmente otro personaje con inventario que la base de datos mantiene indefinidamente. Con decay, los personajes abandonados eventualmente liberan peso — pero conviene que el precio compense al menos parcialmente ese costo de largo plazo, no verlo solo como ingreso puntual.

### 5.4 La decisión que resuelve el pay-to-win ✅ **DECIDIDO** *(pieza clave — revisada en rev. 7)*

**El problema detectado:** en la mayoría de los MMOs el terreno es infinito o instanciado, así que vender slots solo vende "otra historia para jugar". **Pero en este juego el terreno es finito y disputado** (housing urbano + claims estilo Rust). Si cada personaje pudiera reclamar su propia casa y su propio claim, entonces **comprar slots = comprar territorio = pay-to-win encubierto** sobre el recurso más escaso del juego.

> ⚠️ **Corrección de rev. 7:** la solución original (sección 5.4, rev. 1-6) trataba housing y claims como un mismo problema, resuelto poniendo el límite de ambos **por cuenta**. Rev. 7 separa los dos sistemas porque tienen dueños distintos:

**La solución adoptada (rev. 7):**

> ### 🏠 El housing urbano es **POR CUENTA**. Los claims fuera de ciudad son **EXCLUSIVOS DE CLANES**.

- **Housing urbano** (instanciado, barato — sección 2.3): sigue el criterio anterior sin cambios. Una cuenta tiene un cupo de propiedad urbana **en cada mundo donde tenga personajes** (precisión de rev. 5, sección 2.13 — un límite global entre shards sería arbitrario porque son economías separadas sin ventaja cruzada).
- **Claims fuera de ciudad** (construcción libre estilo Rust — sección 2.2-2.4): dejan de ser alcanzables por una cuenta individual, sin importar cuántos personajes o slots tenga. **Solo un clan puede reclamar tierra fuera de ciudad.** Ver sección 5.4.1 para el requisito de fundación.

**Por qué esto es una solución *más fuerte* contra el pay-to-win, no solo distinta:** con el límite por cuenta (rev. 1-6), técnicamente seguía existiendo una ruta indirecta —comprar más slots aumenta cuántas cuentas alternativas podría operar una sola persona—. Con claims exclusivos de clan, **ninguna cantidad de dinero gastado en slots acerca a un jugador a tener un claim**: hace falta organizarse con otros y conseguir los ítems de fundación (sección 5.4.1), que nunca se venden.

Consecuencias, todas positivas:

- Los slots extra sirven exclusivamente para **probar otro arquetipo, otra build, otra historia** — nunca para acaparar más mundo, ni siquiera indirectamente.
- La monetización queda limpia y defendible ante la comunidad (el estándar que le ganó buena reputación a GW2: "cero pay-to-win, todo cosmético").
- **Reduce la cantidad total de claims en el mundo** (menos "dueños" posibles: clanes, no cuentas), lo que ayuda directamente al problema de crecimiento de RAM de sección 2.2.
- Refuerza el pilar social del juego: el territorio deja de ser un logro individual y pasa a ser un logro de grupo.

**Si en el futuro se quisiera permitir una propiedad urbana adicional por cuenta:** que sea un producto **separado y explícito** ("slot de propiedad adicional"), no un efecto colateral de comprar un personaje. Así el jugador sabe exactamente qué está comprando, y se puede precificar distinto — por ejemplo, con **upkeep más caro por cada propiedad extra**, para que mantener varias casas urbanas no sea gratis.

### 5.4.1 Fundación de clanes: la puerta de entrada al territorio 🟡 **TENTATIVO — NUEVO EN REV. 7**

**Fundar un clan debe ser difícil a propósito.** No alcanza con juntar el número mínimo de jugadores: hace falta además conseguir **ítems especiales de fundación**.

**Por qué:** si fundar un clan fuera trivial, el sistema de claims exclusivos de clan (sección 5.4) no protegería nada — cualquier grupo chico crearía un "clan" de fachada solo para reclamar tierra, y la barrera contra el pay-to-win se volvería cosmética. El costo de fundación real es lo que hace que el territorio siga siendo escaso y significativo.

**Reglas de diseño para los ítems de fundación:**

- **Nunca comprables** (cash shop ni con dinero real) — si se pudieran comprar, el pay-to-win vuelve a entrar por esta puerta en vez de por los slots.
- **La fuente no puede depender de ya tener territorio.** Si el ítem solo dropeara dentro de un claim o de contenido que requiere clan, nadie podría fundar el primer clan — problema de huevo y gallina. La fuente debe ser accesible a jugadores sin clan: drop de mundo/boss, crafteo con materiales de zonas abiertas, o una cadena de quests.
- El costo debe **escalar con el tamaño del clan** o con la ambición del claim (un clan grande que quiere mucho terreno paga más que uno chico), para frenar la concentración de tierra en pocos clanes (ver riesgo en sección 8).

🔴 **ABIERTO:** número mínimo de miembros, ítems concretos y su fuente, si la fundación es un evento único o si expandir el territorio de un clan ya fundado tiene su propio costo incremental.

### 5.5 Sistema de "renacer" / prestigio 🔴 **ABIERTO — no implementar por ahora**

Si algún día se quiere ofrecer un reinicio real, **no debe ser gratis ni casual**. Debe ser una decisión consciente y cara: se "retira" un personaje de alto nivel a cambio de algo permanente en la cuenta (cosmético o de conveniencia, **no poder**), y el personaje viejo queda archivado o se convierte en NPC/legado.

Eso sería un sistema de prestigio **deliberado**, no el resultado accidental de "no me gustó mi build, hago otro".

### 5.6 Riesgos / puntos débiles

- Con el límite de propiedad por cuenta, un jugador con 5 personajes puede sentir que sus personajes secundarios son "ciudadanos de segunda" sin casa propia. **Vale la pena pensar cómo comunicar esto** para que se lea como anti-pay-to-win y no como mezquindad.
- Falta definir el resto del modelo de monetización. Los slots solos no sostienen un MMO.

### 5.7 Decisiones pendientes

- 🔴 **Modelo de monetización general** (¿buy-to-play? ¿F2P con cosméticos? ¿suscripción?). Esta decisión es grande y todavía no se tocó.
- 🔴 Cuántas propiedades por cuenta exactamente (¿1 casa urbana + 1 claim? ¿más?).
- 🔴 Si los personajes de una misma cuenta comparten banco/almacenamiento.
- 🔴 Qué pasa con la propiedad si el jugador borra el personaje que la fundó (con propiedad por cuenta esto debería ser trivial — conviene confirmarlo en la implementación).

---

### 5.8 Comparativa de mercados: EE.UU. vs LATAM 📋 **ANÁLISIS — NUEVO EN REV. 6**

> **Nota:** la decisión vigente sigue siendo **EE.UU.** (sección 2.12). Esta sección documenta el análisis completo para que la decisión pueda revisarse con información, no por intuición, si el contexto cambia.

#### 5.8.1 El argumento a favor de LATAM

**El MMORPG 2D no es un género cualquiera en Latinoamérica — es *el* género.** No es nostalgia difusa: es una escena viva.

- **Argentum Online** es un MMORPG **argentino de 1999** que liberó su código fuente, lo que generó un ecosistema masivo de servidores creados por jugadores. Ganó popularidad masiva en países hispanohablantes y hoy tiene **una de las comunidades más grandes y dedicadas de MMORPGs clásicos en Latinoamérica**. Sigue con desarrollo activo en 2026.
- **Tibia** — la referencia estética más cercana a este proyecto — **mantiene servidores alojados en Brasil específicamente para la comunidad latinoamericana**, y su modo freemium está adaptado a precios locales.
- Existen foros enteros dedicados a lanzamientos de MMORPGs 2D apuntados a LATAM, con proyectos que publicitan explícitamente "servidor dedicado LATAM, 30–40 ms".

**Conclusión:** en EE.UU. el MMORPG 2D es un nicho nostálgico. En LATAM es una cultura viva, con comunidad, streamers, foros y jugadores que ya entienden exactamente qué es este tipo de servidor y qué esperar de él.

#### 5.8.2 El problema de LATAM: monetización

Esa misma comunidad **está acostumbrada a servidores privados gratuitos**. Cobrar USD 5 por un slot de personaje a un público que creció con servidores gratis es sustancialmente más difícil que cobrárselo a un jugador estadounidense. Sumar a eso: medios de pago fragmentados, inflación y menor poder adquisitivo.

⚠️ **Esto impacta directamente el modelo de sección 5.3.** Si en algún momento se apunta a LATAM, el esquema de precios en dólares plenos probablemente no funcione y haya que adaptar precios por región (como hace Tibia).

#### 5.8.3 El veredicto honesto

| | **LATAM** | **EE.UU.** |
|---|---|---|
| **Probabilidad de tracción** | ✅ Alta — ventaja cultural, género establecido | ❌ Baja — nicho, competencia brutal en Steam |
| **Ingreso por jugador** | ❌ Bajo — cultura de servidores gratis | ✅ Alto |
| **Facilidad para construir comunidad** | ✅ Alta — idioma propio, códigos culturales compartidos | ❌ Baja — comunidad en inglés desde Argentina |
| **Costo de hosting** | ❌ 2×–4× (sección 2.11.2) | ✅ Barato (Contabo) |
| **Costo de equivocarse** | ✅ Bajo | ❌ Alto |

**El punto central:** la **tracción es oxígeno**. Un MMO vacío está muerto sin importar cuánto pague cada jugador. Y el activo más grande de un desarrollador solo o de equipo chico **es la comunidad que puede construir personalmente** — en un MMO, la comunidad *es* el producto. Estar presente en un Discord hispanohablante siendo uno mismo, entendiendo los códigos y respondiendo rápido, es una ventaja real que en inglés se pierde casi por completo.

**Apuesta con mejor relación riesgo/recompensa para un primer MMO:** validar en LATAM y expandir a EE.UU. después es más defendible que el orden inverso. Es más barato equivocarse, y si el juego prende, expandirlo al mercado angloparlante es un problema mucho mejor que *"tengo un juego pulido en inglés que nadie descubrió"*.

**Argumento a favor de mantener EE.UU.:** apuntar al mercado grande desde el inicio evita el costo de reposicionar el producto después, y el ahorro de hosting da margen para pagar núcleos dedicados (sección 2.12.1). Es una decisión legítima, solo que con más riesgo de descubrimiento.

🔴 **PENDIENTE:** revisar esta decisión si al lanzar el playtest la tracción angloparlante resulta muy baja.

---

### 5.9 Política de reinversión ✅ **NUEVO EN REV. 6**

**Propuesta original:** cuando el servidor principal se solvente y genere ingreso adicional, ese excedente va directo a un servidor nuevo.

**La idea es sana, pero el orden de prioridades necesita corrección.**

#### 5.9.1 ⚠️ Por qué el segundo servidor NO es el primer destino del excedente

> **Abrir un shard con housing persistente es un compromiso casi permanente.**

Si se abre el shard LATAM y a los seis meses no se puede sostener, cerrarlo significa que **la gente pierde sus casas, sus claims y todo lo que construyó**. Eso no es un mal trimestre: es la muerte reputacional del proyecto, y en un género donde la confianza en la permanencia del mundo es el fundamento de todo, no se recupera.

**Por lo tanto: hacen falta varios meses de runway cubiertos antes de asumir esa responsabilidad, no break-even.**

#### 5.9.2 Orden correcto de prioridades del excedente

| Prioridad | Destino | Por qué |
|---|---|---|
| **1.º** | **Fondo de reserva** | Cubrir varios meses de operación ante caídas de ingreso. Protege la permanencia del mundo, que es el activo más importante del juego |
| **2.º** | **Escalar el servidor principal** | Recordar sección 2.2: **el consumo de RAM crece con las construcciones acumuladas**, no con los jugadores. El shard 1 va a necesitar upgrades por sí solo con el tiempo. Ese gasto es inevitable y viene antes que expandirse |
| **3.º** | **Segundo shard** | Solo cuando se cumplan los criterios de sección 2.13.2 (el primero saturado) **y** exista el fondo de reserva del punto 1 |

#### 5.9.3 El umbral de "se solventa solo" es engañosamente bajo

Un VPS cuesta poco. Que el juego cubra el costo del servidor **no significa que sea sostenible** — significa apenas que no pierde plata en infraestructura.

**Umbral real recomendado para considerar cualquier expansión:**

> Cubre el servidor **+** tiene fondo de reserva **+** compensa mínimamente el tiempo de desarrollo.

🔴 **PENDIENTE:** definir el número concreto de meses de reserva antes de habilitar la apertura de un segundo shard.

---

## 6. Coherencia del diseño: cómo encajan las piezas

```
                     ARQUETIPO BASE (Guerrero / Mágico / Rogue)
                                    │
                                    ▼
                  ┌─────── PROGRESIÓN POR USO ───────┐
                  │   (la conducta genera progreso)  │
                  └──────────────┬───────────────────┘
                                 ▼
                        CAP TOTAL DE SKILLS
                     (fuerza sacrificio y elección)
                                 │
                                 ▼
              RED DE SKILLS ABIERTA (sin muros de clase)
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                  ▼
      ROLLS CONTINUOS      DESCUBRIMIENTO      GEAR QUE MODIFICA
      "elegí 1 de 3"       (tomos, NPCs,       COMPORTAMIENTO
      + núcleo garantizado  combos de uso)
              │                  │                  │
              └──────────────────┼──────────────────┘
                                 ▼
                    IDENTIDAD EMERGENTE + TÍTULO
                                 │
                                 ▼
                   PERSONAJE ÚNICO E IRREPETIBLE
                                 │
                                 ▼
        ┌────────────── ANCLAJE AL MUNDO ──────────────┐
        │  Housing (por cuenta) + Claims (por clan)     │
        │  Gremio, economía, vínculos sociales          │
        │  → razones para NO tirar el personaje         │
        └───────────────────────────────────────────────┘
```

**Por qué el conjunto es coherente:** cada sistema refuerza al resto en lugar de pelearse con él.

- La progresión por uso **necesita** el cap, o degenera en "todos hacen todo".
- El cap **necesita** poder horizontal, o degenera en "hay un único set óptimo de sacrificios".
- La capa roguelite **necesita** el núcleo garantizado y los rerolls, o degenera en frustración.
- Los rolls continuos (sección 4.3) **necesitan** existir, o el sistema empuja al alt-spam.
- El anclaje al mundo (housing, gremio) **necesita** que el housing urbano sea por cuenta y los claims sean exclusivos de clan, o la monetización se vuelve pay-to-win.

**Cada una de esas dependencias es un punto donde un cambio futuro puede romper algo lejano. Consultarlas antes de modificar.**

---

## 7. Preguntas abiertas globales

Ordenadas por impacto: las primeras condicionan a las demás.

### 7.1 Bloqueantes

**Resueltos en rev. 2:**

- ✅ ~~¿Cómo es el combate?~~ → **Acción en tiempo real tipo Hades.**
- ✅ ~~¿Hay PvP?~~ → **Sí.** (Alcance concreto: se define en el entorno del proyecto.)

**Resuelto en rev. 4:**

- ✅ ~~¿Cuál es la base de jugadores objetivo geográficamente?~~ → **Estados Unidos / angloparlante.** Región de hosting recomendada: **US Central (St. Louis)**, con Contabo nuevamente viable (sección 2.12).

**Bloqueantes que siguen abiertos:**

1. 🔴 **¿Cuál es el tick rate objetivo?** Define todo el presupuesto de CPU (sección 2.9). Se define en el entorno del proyecto.
2. 🔴 **¿Hay wipes?** Rust los usa por necesidad técnica. Con housing y economía, un wipe es socialmente costosísimo. Si no hay wipes, el decay debe ser mucho más agresivo y el presupuesto de RAM más grande.
3. 🔴 **¿Se pueden raidear las bases de otros jugadores?** Con PvP confirmado, esta pregunta pasa a primer plano. Define si los claims son refugios seguros o objetivos, lo que cambia por completo la relación del jugador con la construcción — y por lo tanto cuánto construye y cuánta carga genera en el servidor.
4. 🔴 **¿Cloud VPS o VDS?** Con público estadounidense el ahorro de Contabo da margen para pagar núcleos dedicados. Decidir si se arranca directamente en VDS (sección 2.12.1).

### 7.2 Estructurales

4. Modelo de monetización general (más allá de los slots).
5. Tamaño del mundo.
6. Cuántas skills tiene la red en total.
7. Qué proporción del contenido está gated por descubrimiento vs. disponible siempre.
8. ⭐ **¿Los personajes pueden transferirse entre shards?** (La propiedad no puede — queda en el mundo donde se fundó. Ver sección 2.13.3.)
9. ⭐ **¿Qué métrica concreta dispara la apertura del shard LATAM?** Definir el umbral por adelantado evita abrirlo por presión emocional de la comunidad.

### 7.3 De calibración (solo se resuelven probando)

8. Valor del cap de skills.
9. Frecuencia de los momentos de descubrimiento.
10. Rareza de los ítems de reroll.
11. Parámetros de decay y upkeep.
12. Peso de la sinergia en el "1 de 3".

---

## 8. Riesgos principales del proyecto

*Reordenada en rev. 2 según las nuevas definiciones.*

| Riesgo | Severidad | Mitigación |
|---|---|---|
| **Alcance excesivo** — tres sistemas ambiciosos en paralelo, ahora con combate de acción y PvP encima | 🔴 Alta | Priorizar: definir cuál pilar es el MVP y cuáles se agregan después |
| **Latencia inaceptable** para la base de jugadores | 🟢 Baja ⬇️ | Bajó en rev. 4: con servidor en US Central y público estadounidense, la latencia queda controlada |
| **Cerrar un shard por falta de fondos** → los jugadores pierden lo construido = muerte reputacional | 🔴 Alta ⭐ | **Nuevo en rev. 6.** Fondo de reserva de varios meses **antes** de abrir cualquier shard nuevo (sección 5.9.1) |
| **Baja tracción en el mercado angloparlante** — nicho + competencia brutal en Steam | 🟠 Media-alta ⭐ | Nuevo en rev. 6: revisar la decisión de mercado si el playtest muestra poca tracción (sección 5.8.3) |
| **Fragmentar una comunidad chica** al abrir el shard LATAM demasiado temprano → dos mundos vacíos en vez de uno vivo | 🔴 Alta | Abrir el segundo shard solo cuando el primero tenga problemas de capacidad, no por demanda regional (sección 2.13.2) |
| **Migración de BD para agregar shards** si no se previó el `world_id` desde el inicio | 🔴 Alta ⭐ | **Nuevo en rev. 5.** Poner el campo desde la primera línea de código, aunque valga siempre 1 (sección 2.13.1) |
| **Costo operativo de dos shards** (mantenimiento, moderación, eventos en dos husos horarios) | 🟠 Media ⭐ | Nuevo en rev. 5: suele pesar más que el costo del servidor en un proyecto chico (sección 2.13.4) |
| **Calibración del combate hecha desde alta latencia** → feel mal ajustado para el público real | 🔴 Alta | El desarrollador está lejos del servidor. Testers en EE.UU. desde temprano + latencia simulada localmente + instrumentación de ping (sección 2.12.3) |
| **Contenido escrito en español y traducido después** | 🟠 Media ⭐ | Nuevo en rev. 4: desarrollar en inglés desde el inicio, no retrofitear (sección 2.12.2) |
| ~~Ruteo latinoamericano inestable~~ | ⚪ No aplica | Descartado en rev. 4 por el cambio de mercado objetivo |
| ~~Costo de hosting 2×–4× mayor~~ | ⚪ No aplica | Descartado en rev. 4: Contabo vuelve a ser viable |
| **Sin decay desde el día 1** → el mundo no entra en RAM al mes 2 | 🔴 Alta | Implementar decay antes que el sistema de construcción, no después |
| **Pocos clanes grandes acaparan todo el terreno construible** | 🟠 Media-alta ⭐ | Nuevo en rev. 7: límite de claims/piezas por clan y costo de fundación que escale con el tamaño/ambición (sección 5.4.1) |
| **Ítems de fundación de clan mal definidos → problema de huevo y gallina** (hace falta clan para conseguir territorio, pero el ítem no debería depender de ya tenerlo) | 🟡 Media-baja ⭐ | Nuevo en rev. 7: la fuente debe ser accesible sin clan (drop de mundo/boss, crafteo, quest) y nunca comprable (sección 5.4.1) |
| **Contención de CPU en vCPU compartido** → tick rate inestable, rubber-banding | 🔴 Alta ⬆️ | Ascendió de "media-baja" en rev. 2: el combate de acción es el peor caso para CPU sobrevendida. Considerar VDS desde el inicio |
| **Balance de red abierta con PvP** — exponencialmente más difícil | 🟠 Media-alta | Poder horizontal **obligatorio** (sección 3.7) + aceptar que el balance perfecto no existe |
| **Cheating** — con servidor no autoritativo, cheats en la primera semana | 🟠 Media-alta ⬆️ | Nuevo en rev. 2: servidor autoritativo desde el diseño, nunca confiar en el cliente para movimiento/daño |
| **Grindeo degenerado** de progresión por uso | 🟠 Media | Ganancia contextual + rendimientos decrecientes |
| **Rerolls mal calibrados** matan el sistema o frustran | 🟡 Media-baja | Solo se calibra con jugadores reales; empezar restrictivo y aflojar |
| **Azar percibido como injusto** en PvP | 🟢 Baja ⬇️ | Bajó en rev. 2: el combate de acción hace que la habilidad manual absorba la asimetría de build (sección 4.8) |

---

## 9. Checklist de validación antes de avanzar

**Infraestructura**
- [x] ✅ **Definir base de jugadores objetivo** → **EE.UU. / angloparlante**
- [ ] 🔴 Decidir región: **US Central (St. Louis)** recomendada — confirmar
- [ ] 🔴 Decidir **Cloud VPS vs VDS** (núcleos dedicados) para el tick rate
- [ ] 🔴 **Conseguir testers en EE.UU.** antes de calibrar el feel del combate
- [ ] 🔴 Configurar **latencia simulada** en el entorno local para poder probar a ~30 ms
- [ ] Instrumentar el juego para registrar el ping de cada tester junto con su feedback
- [ ] Definir todo el contenido y la UI **en inglés** desde el inicio
- [ ] 🔴 **`world_id` como campo de primera clase en todo el esquema de BD desde el día uno** (personajes, casas, claims, estructuras, economía) — aunque solo exista un shard
- [ ] 🔴 Scopear por mundo el indexado espacial y toda consulta de proximidad
- [ ] Definir motor/lenguaje del servidor
- [ ] Definir tick rate objetivo
- [ ] Prueba de carga con bots construyendo, **con el tick rate real del combate**
- [ ] Implementar decay **antes** de abrir la construcción a jugadores
- [ ] Implementar indexado espacial desde el inicio (retrofitear esto después es doloroso)
- [ ] Verificar que el guardado sea asíncrono y no bloquee el loop
- [ ] Confirmar arquitectura de servidor autoritativo (anti-cheat estructural)
- [ ] Confirmar protección DDoS del proveedor

**Diseño de progresión**
- [x] ✅ Definir combate → **acción en tiempo real tipo Hades**
- [ ] Auditar que ninguna skill sea estrictamente superior a otra (poder horizontal obligatorio con PvP)
- [ ] Listar el set inicial de skills por arquetipo
- [ ] Definir el núcleo garantizado (3–4 por arquetipo)
- [ ] Fijar un valor tentativo del cap y probarlo
- [ ] Diseñar la mitigación anti-grindeo pasivo

**Roguelite**
- [ ] Definir los triggers de descubrimiento
- [ ] Prototipar el "1 de 3" y probar cómo se siente
- [ ] Definir fuente de los rerolls (nunca cash shop)

**PvP** *(nuevo en rev. 2 — detalles técnicos en el entorno del proyecto)*
- [ ] Definir zonas y reglas de enfrentamiento
- [ ] Definir si los claims son raideables
- [ ] Definir consecuencias de la muerte en PvP (pérdida de ítems, de skill, nada)

**Cuentas y monetización**
- [ ] Confirmar límite de housing urbano **por cuenta**
- [ ] 🔴 Definir ítems de fundación de clan y su fuente (nunca comprable, no dependiente de ya tener territorio — sección 5.4.1)
- [ ] 🔴 Definir número mínimo de miembros para fundar clan
- [ ] 🔴 Definir cuántos meses de reserva se exigen antes de habilitar un segundo shard
- [ ] Definir el umbral real de sostenibilidad (servidor + reserva + compensación de tiempo)
- [ ] Si alguna vez se apunta a LATAM: rediseñar precios por región, no cobrar en USD plenos
- [ ] Definir el modelo de monetización general
- [ ] Decidir precio plano vs. escalonado de slots

---

## 10. Registro de decisiones revertidas

Se documentan explícitamente porque son las que más fácilmente se re-proponen por accidente en el futuro.

| Idea original | Estado | Por qué se descartó |
|---|---|---|
| **Pool de skills fijado al crear el personaje** | ❌ Descartada | Un mal roll de nacimiento incentiva abandonar el personaje. Reemplazada por **rolls continuos** (sección 4.3) |
| **Meta-progresión de cuenta que mejora probabilidades** | ❌ Descartada | Incentiva alt-spam, contradice el anclaje social, y carga la base de datos. Reemplazada por **meta-progresión solo cosmética/conveniencia** (sección 5.2) |
| **Terreno reclamable por personaje** | ❌ Descartada | Convertía la venta de slots en pay-to-win sobre un recurso escaso. Reemplazada por **terreno por cuenta**, luego refinada en rev. 7 (sección 5.4) |
| **Claims fuera de ciudad limitados por cuenta** (rev. 1-6) | 🔄 Superada en rev. 7 | Seguía dejando una ruta indirecta de pay-to-win (más slots = más cuentas alternativas posibles). Reemplazada por **claims exclusivos de clan**, con fundación gateada por ítems no comprables (sección 5.4, sección 5.4.1) |

---

## 11. Glosario

- **CCU** — Concurrent Users. Jugadores conectados simultáneamente.
- **Claim** — Territorio reclamado fuera de las ciudades donde se puede construir.
- **Decay** — Degradación y eventual borrado automático de estructuras inactivas o sin upkeep.
- **Lag compensation** — Técnicas para que el combate se sienta justo pese a la latencia (rollback, reconciliación).
- **Rubber-banding** — Efecto de "goma elástica": el personaje se teletransporta hacia atrás porque el servidor corrigió su posición. Síntoma típico de CPU saturada o latencia alta.
- **Servidor autoritativo** — Arquitectura donde el servidor valida todo y el cliente solo sugiere. Indispensable con PvP para evitar cheats.
- **Meta** — El conjunto de builds/estrategias que la comunidad considera óptimas.
- **Poder horizontal** — Opciones fuertes en situaciones distintas, en oposición al poder vertical (simplemente números más grandes).
- **Shard** — Instancia independiente del mundo, con sus propios personajes, construcciones y economía. Dos shards son mundos distintos, no copias sincronizadas.
- **Shardear** — Dividir el mundo en varios procesos/instancias para repartir la carga.
- **Tick rate** — Frecuencia con la que el servidor actualiza el estado del juego.
- **Upkeep** — Costo de mantenimiento periódico para conservar una propiedad.
- **Wipe** — Borrado total del progreso/construcciones del servidor, generalmente periódico.

---

## 12. Estrategia de contenido y comunidad: streaming de desarrollo 🟡 **TENTATIVO — NUEVO EN REV. 8**

### 12.1 Qué es

Transmitir el desarrollo del juego en vivo, mostrando decisiones de diseño en tiempo real, **sin mostrar código ni herramientas de asistencia por IA**. El foco del stream no es "mirenme programar" sino "miren cómo se construye un MMO y qué decisiones hay que tomar" — exploración de mapa, sistemas, arte, balance, feedback de la comunidad sobre esas decisiones.

### 12.2 Por qué así

Un MMO 2D indie hecho por una sola persona avanza lento en términos de progreso visible; si el contenido dependiera de mostrar features terminadas, el ritmo de stream sería insostenible. Narrar el *proceso de decisión* (dudas, cambios de rumbo, cosas descartadas) genera contenido incluso en sesiones de bajo avance técnico, y además construye la primera comunidad del juego mientras se lo hace — algo que un MMO necesita de todos modos para sobrevivir el lanzamiento.

**Ciclo esperado:** stream → interacción/decisiones con la comunidad → clips cortos → gente descubre el juego → Discord/wishlist → vuelven al próximo stream.

**Decisión operativa recomendada:** por defecto compartir pantalla del **juego corriendo** (play mode), no el editor. Evita la fricción de tener que cortar transmisión o tapar pantalla cada vez que se abre código, y mantiene consistente la regla de "sin mostrar código ni IA" sin que dependa de acordarse en el momento.

### 12.3 Riesgos / puntos débiles

- **Audiencia inicial será prácticamente cero.** El valor temprano del stream no es tener espectadores en vivo, sino generar el archivo de VODs/clips que sirve después para redes cuando recién ahí empiece a entrar audiencia.
- **Tensión entre el ritmo de stream y el trabajo técnico profundo.** Partes del desarrollo más difíciles de mostrar y que requieren concentración sin interrupciones (en este proyecto, específicamente todo lo de sección 2: networking server-authoritative, decay, indexado espacial) no son buen contenido de stream y compiten por el mismo tiempo. Conviene separar: streams para diseño/arte/balance/contenido, trabajo técnico duro fuera de cámara.
- 🔴 **Tensión sin resolver con sección 2.12 (mercado objetivo angloparlante):** el idioma natural del desarrollador para conectar con una comunidad en vivo es el español, pero la decisión de mercado vigente es EE.UU./inglés, con toda la comunidad, Discord y marketing pensados en inglés (sección 2.12.2). Si el stream y la comunidad que genera terminan siendo mayormente hispanohablantes, se reabre parcialmente la discusión de sección 5.8 (comparativa EE.UU. vs. LATAM) por una vía no técnica: la tracción real de comunidad puede terminar siendo LATAM aunque el producto esté diseñado en inglés para EE.UU. No es necesario resolver esto ahora, pero conviene tenerlo presente al decidir en qué idioma se streamea.

### 12.4 Decisiones pendientes

- 🔴 Idioma del stream (ver tensión con sección 2.12 arriba).
- 🔴 Encuadre público del proyecto: presentarlo como "estoy creando mi propio MMORPG 2D" en vez de "development stream" tiene más gancho para audiencia no técnica — confirmar si se adopta como framing por defecto.
- 🔴 Cadencia: si hay seguimiento semanal de avances para convertirlos en ideas de stream/clips, o si se decide sesión a sesión.
