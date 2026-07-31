import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/api_constants.dart';

/// Upload proxy vers R2 — jamais de presigned PUT direct (CORS), pattern
/// déjà validé sur Animaginee: octet-stream + header x-file-type.
class UploadService {
  final _dio = Dio();

  Future<String> uploadFile(File file, {required String folder}) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = _contentTypeFor(ext);

    final res = await _dio.post(
      '${ApiConstants.baseUrl}${ApiConstants.upload}',
      data: bytes,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/octet-stream',
          'x-file-type': contentType,
          'x-folder': folder,
        },
      ),
    );
    return res.data['url'] as String;
  }

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'image/jpeg';
    }
  }
}
