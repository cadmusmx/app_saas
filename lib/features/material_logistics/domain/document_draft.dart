/// Documento del **bucket de cabecera** (nivel arribo):
///   archivo GENERAL que aplica a todo el registro (foto de unidad, material en unidad, PDF),
///   no a un sitio.
///
/// Shape del contrato: `{ nombre, archivo, mimeType }` (`archivo` = llave S3).
/// `localPath` apunta al archivo local pendiente de subir;
/// el holder lo reemplaza por la llave final en el submit y lo pone en `null`.
///
/// En update, `documentos` es **reemplazo total** (no diff):
///   el holder manda la lista completa vigente si cambió, o la omite si no.
///   Por eso este modelo no necesita baseline propio (el holder compara contra el original).
class DocumentDraft {
  String nombre;
  String archivo; // llave S3 (vacío mientras `localPath` esté pendiente)
  String mimeType;
  String? localPath; // ruta local pendiente de subir; null = ya tiene llave

  DocumentDraft({required this.nombre, required this.archivo, required this.mimeType, this.localPath});

  /// Desde la lectura del detalle (`/{folio}` → `documentos[]`).
  factory DocumentDraft.fromRead(Map<String, dynamic> j) => DocumentDraft(
    nombre: j['nombre']?.toString() ?? '',
    archivo: j['archivo']?.toString() ?? '',
    mimeType: j['mimeType']?.toString() ?? '',
  );

  DocumentDraft copy() => DocumentDraft(nombre: nombre, archivo: archivo, mimeType: mimeType, localPath: localPath);

  /// Igualdad de contenido persistido (ignora `localPath`): base para detectar
  /// cambios contra el original en edición.
  bool sameAs(DocumentDraft o) => nombre == o.nombre && archivo == o.archivo && mimeType == o.mimeType;

  /// Forma de envío (create y reemplazo total en update): `{ nombre, archivo, mimeType }`.
  Map<String, dynamic> toJson() => {'nombre': nombre, 'archivo': archivo, 'mimeType': mimeType};
}
