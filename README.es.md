# ai bibliography check

[English](README.md)

![Vista previa de ai bibliography check](preview.svg)

Panel bilingüe de Omarchy / Quickshell para revisar una bibliografía pegada antes de entregarla. Busca autores o años ausentes, DOI/URL duplicados, mezcla de estilos de año y señales de redacción formulaica de aismell.

Es un revisor editorial, no una base de datos de citas ni un detector forense de IA. No afirma que un paper exista, que un DOI resuelva ni que los metadatos coincidan con Crossref, Scopus, Google Scholar u otro catálogo.

## Qué hace

- Lee primero la selección primaria de Wayland y luego el portapapeles normal para precargar el panel.
- Acepta hasta 12.000 caracteres.
- Agrupa entradas separadas por líneas en blanco o marcadores reconocibles como `[1]`, `1.` o `-`.
- Marca entradas sin un autor reconocible o sin un año de publicación de cuatro dígitos.
- Detecta DOI/URL repetidos y entradas completas duplicadas.
- Avisa si la lista mezcla años entre paréntesis, como `(2024)`, con años sueltos, como `2024.`.
- Envía los primeros 3.000 caracteres al analizador de aismell para buscar redacción formulaica; las comprobaciones estructurales cubren todo el texto pegado.
- Mantiene el texto original editable y nunca modifica automáticamente la aplicación enfocada.

## Instalación

```bash
omarchy plugin add https://github.com/brm-src/ai-bibliography-check.git --enable --yes
```

No requiere sudo ni pkexec. Necesita Omarchy/Hyprland, Quickshell, Python 3, `curl` y `wl-paste`.

El atajo opcional `Super + Shift + B` se configura aparte:

```bash
bash ~/.config/omarchy/plugins/io.github.brm-src.ai-bibliography-check/configure-shortcut.sh
```

Para quitar solo el atajo:

```bash
bash ~/.config/omarchy/plugins/io.github.brm-src.ai-bibliography-check/configure-shortcut.sh --remove
```

Para quitar el plugin:

```bash
omarchy plugin remove io.github.brm-src.ai-bibliography-check --yes
```

## Uso

1. Copia una bibliografía o pégala en el panel.
2. Deja una entrada por línea o separa las entradas con líneas en blanco.
3. Presiona `revisar`.
4. Corrige primero los hallazgos de severidad alta y luego decide si los medios aplican realmente a tu estilo de citación.

Presiona `Escape`, `Super + W` o haz clic fuera de la tarjeta para cerrar. El pie `powered by: aismell` abre el sitio del proyecto.

## Privacidad y flujo de datos

Consulta [PRIVACY.md](PRIVACY.md).

- Abrir el panel solo lee la selección primaria o el portapapeles para precargar el editor.
- El plugin no escribe la bibliografía, los reportes ni el contenido del portapapeles en disco.
- Al presionar `revisar`, el texto se envía por HTTPS al Worker público de aismell.
- El Worker no tiene base de datos de aplicación, KV, R2, Durable Objects ni almacenamiento de envíos, y responde con `Cache-Control: no-store`.
- No pegues contraseñas, claves privadas, material confidencial ni texto que deba permanecer offline.

## Límites importantes

- No es un verificador factual de bibliografía. No puede probar que una cita sea real ni que sus metadatos sean correctos.
- El reconocimiento de autores es deliberadamente conservador y puede marcar estilos válidos que no comiencen con un autor convencional.
- Aismell solo ve los primeros 3.000 caracteres para señales lingüísticas; las comprobaciones estructurales cubren los 12.000 caracteres.
- El endpoint requiere conexión a internet.
- Un hallazgo medio es una invitación a revisar, no un veredicto.

## Comprobaciones de desarrollo

Desde la raíz del repositorio:

```bash
python3 -m pytest tests -q
python3 -m py_compile bibliography_check.py
bash -n configure-shortcut.sh
qmllint -I /usr/share/omarchy/shell BarButton.qml BibliographyCheck.qml
omarchy plugin validate .
git diff --check
```

## Licencia

MIT. Consulta [LICENSE](LICENSE).
