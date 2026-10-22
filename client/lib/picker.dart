import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'api.dart';

class PickedImage {
  final Uint8List bytes;
  final String name;
  const PickedImage(this.bytes, this.name);

  int get sizeKb => (bytes.length / 1024).round();
}

/// 选图并压到合理尺寸。
///
/// 用 image_picker 的字节接口（XFile.readAsBytes），不依赖 dart:io，
/// 桌面端与移动端走同一套代码。
Future<PickedImage?> pickImageBytes() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 88,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  if (bytes.length > 4 * 1024 * 1024) {
    throw ApiException('图片请小于 4MB（当前 ${(bytes.length / 1024 / 1024).toStringAsFixed(1)}MB）');
  }
  return PickedImage(bytes, file.name.isEmpty ? 'image.jpg' : file.name);
}
