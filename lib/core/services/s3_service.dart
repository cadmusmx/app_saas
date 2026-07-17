import 'dart:io';
import 'dart:typed_data';
import 'package:aws_client/s3_2006_03_01.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gaso_tenant_app/core/logging/debug_log.dart';
import 'package:gaso_tenant_app/core/config/env.dart';

class S3Service {
  final String _bucket = Env.s3Bucket;
  final String _regionS3 = Env.s3Region;
  final String _accessKey = Env.s3AccessKey;
  final String _secretKey = Env.s3SecretKey;

  Future<String?> uploadFileToS3(File file, String key, [String? contentType]) async {
    // Verificar que el archivo existe
    if (!await file.exists()) {
      throw Exception('El archivo temporal fue eliminado por el sistema');
    }
    Uint8List fileBytes = await file.readAsBytes();
    return await _uploadToS3(fileBytes, key, contentType);
  }

  Future<String?> uploadU8LToS3(Uint8List body, String key, [String? contentType]) async {
    return await _uploadToS3(body, key, contentType);
  }

  Future<String?> _uploadToS3(Uint8List body, String key, String? contentType) async {
    final s3 = S3(
      region: _regionS3,
      credentials: AwsClientCredentials(accessKey: _accessKey, secretKey: _secretKey),
    );

    int attempts = 0;
    while (attempts < 5) {
      try {
        await s3.putObject(bucket: _bucket, key: key, body: body, contentType: contentType);
        return 'https://$_bucket.s3.$_regionS3.amazonaws.com/$key';
      } catch (e) {
        attempts++;
        DebugLog.warning('Intento $attempts fallido: $e');
        // Reintentar en caso de errores comunes
        if (e.toString().contains('SlowDown') || e.toString().contains('HandshakeException')) {
          final delay = Duration(seconds: 2 * attempts);
          await Future.delayed(delay);
          continue;
        }
        DebugLog.error('Error al subir recurso a S3: $e');
        return null;
      }
    }
    return null;
  }

  /// Permite borrar un objeto (imágenes, documentos, etc) de S3
  Future<bool> deleteFromS3(String key) async {
    try {
      final s3 = S3(
        region: _regionS3,
        credentials: AwsClientCredentials(accessKey: _accessKey, secretKey: _secretKey),
      );
      final decodedKey = Uri.decodeComponent(key);
      await s3.deleteObject(bucket: _bucket, key: decodedKey);
      return true;
    } catch (e) {
      DebugLog.warning('$e');
      return false;
    }
  }

  // Método base para obtener datos de S3
  Future<Uint8List?> getFromS3(String key) async {
    try {
      final s3 = S3(
        region: _regionS3,
        credentials: AwsClientCredentials(accessKey: _accessKey, secretKey: _secretKey),
      );
      final decodedKey = Uri.decodeComponent(key);
      GetObjectOutput objectOutput = await s3.getObject(bucket: _bucket, key: decodedKey);
      return objectOutput.body;
    } catch (e) {
      DebugLog.warning('Error obteniendo archivo de S3: $e');
      return null;
    }
  }

  // Descargar ZIP - Multiplataforma
  Future<String?> download(String s3Key, String fileName) async {
    try {
      final bytes = await getFromS3(s3Key);
      if (bytes == null) {
        DebugLog.warning('No se pudieron obtener los datos del archivo');
        return null;
      }
      Directory directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      return filePath;
    } catch (e) {
      DebugLog.warning('Error descargando ZIP: $e');
      return null;
    }
  }
}
