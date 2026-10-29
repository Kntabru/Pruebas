# Diccionarios de Palabreo 1.20

Los cuatro listados originales de CINCO letras en `js/game.js` se mantienen byte por byte. No se ha sustituido su selección ni alterado su orden.

Para SEIS y SIETE letras, `data/words-6-7.json` y su copia cargable `js/words-6-7.js` contienen, para cada longitud y alfabeto (sin tildes / con tildes), 10.000 propuestas admitidas y 3.000 soluciones. Normal y Difícil comparten el listado sin tildes; Tildes utiliza el listado acentuado. Las soluciones siempre forman parte de las propuestas admitidas.

## Fuente, licencia y selección

1. Frecuencia de uso: Hermit Dave, **FrequencyWords**, corpus OpenSubtitles 2018, español, revisión `525f9b560de45753a5ea01069454e72e9aa541c6`. Datos bajo **CC BY-SA 4.0**, código de la fuente MIT. Fuente: https://github.com/hermitdave/FrequencyWords . Archivo concreto, hash y recuentos en `data/selection.json`. La licencia de contenido consta en el README de esa revisión; texto legal incluido en `licenses/frequencywords/CC-BY-SA-4.0.txt`.
2. Filtro ortográfico: diccionario español Hunspell de **Santiago Bosio y colaboradores**, distribuido por LibreOffice y Debian en `hunspell-es 1:25.2.3-1`. Derechos originales: GPL-3+ o LGPL-3+ o MPL-1.1+; se utiliza la opción MPL, versión 2.0. Fuentes completas `.aff` y `.dic`, texto MPL y avisos de Debian se conservan en `licenses/spanish-hunspell/`. Hunspell ejecutado: `1.7.2+really1.7.2-10+b4`.
3. Se consideran solo tokens alfabéticos españoles de 6/7 caracteres, normalizados a Unicode NFC, que Hunspell admite en minúsculas. Se descartan números, guiones, signos, nombres que solo se admiten con mayúscula y tokens no reconocidos.
4. Se agregan variantes normalizadas conservando la frecuencia máxima de cada grafía equivalente; orden descendente por frecuencia, desempate alfabético. Se eligen las primeras 10.000 propuestas y, dentro de estas, las primeras 3.000 como soluciones.
5. En Normal/Difícil se omiten ÁÉÍÓÚÜ y se mantiene Ñ. Tildes conserva ÁÉÍÓÚ. Se excluyen palabras que exigen Ü del listado Tildes: el alfabeto original no distingue Ü y no se quiere admitir una grafía incorrecta ni ampliar el teclado sin petición.

La selección derivada y sus frecuencias se atribuyen a las fuentes anteriores y se distribuyen con los avisos **CC BY-SA 4.0 / MPL-2.0** correspondientes. Los archivos editables de datos y el procedimiento de selección se incluyen. La selección de soluciones está basada en frecuencia de subtítulos, NO en una revisión manual completa: puede contener conjugaciones, regionalismos, lenguaje adulto o palabras poco habituales. **No se afirma que estos listados hayan sido verificados por la RAE.** Las listas se pueden revisar en una tarea posterior sin atribuirles esa validación.

## Reproducir

`tools/select_dictionaries.py` recibe la lista de frecuencias original, la biblioteca Hunspell y el prefijo de los dos archivos del diccionario. La fuente de frecuencias no necesita descargarse para jugar o construir la APK; se incluyen los resultados finales. Su descarga solo es necesaria para repetir la selección. Los hashes de las tres entradas se registran en `data/selection.json`.

```sh
python tools/select_dictionaries.py \
  --frequency /ruta/es_full.txt \
  --hunspell-lib /ruta/libhunspell-1.7.so.0 \
  --hunspell-prefix /ruta/es_ES
```

Frecuencias originales:
https://raw.githubusercontent.com/hermitdave/FrequencyWords/525f9b560de45753a5ea01069454e72e9aa541c6/content/2018/es/es_full.txt

Los nuevos listados son propuestas locales. Su futura carga en el servidor requerirá una migración adaptada al esquema real, separada y revisada; no se han enviado a Supabase.
