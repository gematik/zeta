// Redocly-Plugin für die ZETA-OpenAPI-Dateien.
// Die JSON-Schemas unter src/schemas tragen das Top-Level-Feld `schemaVersion`.
// JSON Schema erlaubt unbekannte Schlüsselwörter, die struct-Regel von Redocly
// nicht. Das Plugin macht das Feld im Schema-Objekt bekannt, damit die Regel
// `struct` sonst unverändert aktiv bleiben kann.
// Ebenso `dependencies`: Die Schemas sind draft-07; OpenAPI 3.1 kennt dafür
// nur dependentRequired/dependentSchemas (dcr-request.yaml, TPM-Zweig).
export default function zetaPlugin() {
  return {
    id: 'zeta',
    typeExtension: {
      oas3(types) {
        return {
          ...types,
          Schema: {
            ...types.Schema,
            properties: {
              ...types.Schema.properties,
              schemaVersion: { type: 'string' },
              dependencies: { type: 'object' },
            },
          },
        };
      },
    },
  };
}
