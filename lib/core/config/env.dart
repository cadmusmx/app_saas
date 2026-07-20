import 'package:envied/envied.dart';
part 'env.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class Env {
  @EnviedField(varName: 'API_URL', defaultValue: 'http://localhost:3000/api')
  static final String apiUrl = _Env.apiUrl;

  @EnviedField(varName: 'S3_BUCKET', defaultValue: '')
  static final String s3Bucket = _Env.s3Bucket;

  @EnviedField(varName: 'S3_REGION', defaultValue: 'us-east-1')
  static final String s3Region = _Env.s3Region;

  @EnviedField(varName: 'S3_ACCESS_KEY', defaultValue: '')
  static final String s3AccessKey = _Env.s3AccessKey;

  @EnviedField(varName: 'S3_SECRET_KEY', defaultValue: '')
  static final String s3SecretKey = _Env.s3SecretKey;
}
