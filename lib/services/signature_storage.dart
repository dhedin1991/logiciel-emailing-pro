import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/signature.dart';
import 'trash_service.dart';

class SignatureStorage {
  static const _key = 'signatures';
  final _storage = const FlutterSecureStorage();

  Future<List<Signature>> loadSignatures() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Signature.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveSignatures(List<Signature> signatures) async {
    final raw = jsonEncode(signatures.map((s) => s.toJson()).toList());
    await _storage.write(key: _key, value: raw);
  }

  Future<void> addSignature(Signature signature) async {
    final signatures = await loadSignatures();
    signatures.add(signature);
    await saveSignatures(signatures);
  }

  Future<void> removeSignature(String id) async {
    final signatures = await loadSignatures();
    final removed = signatures.where((s) => s.id == id).toList();
    signatures.removeWhere((s) => s.id == id);
    await saveSignatures(signatures);
    if (removed.isNotEmpty) {
      await TrashService.instance.add(
        type: 'signature',
        label: removed.first.name,
        payloads: removed.map((s) => s.toJson()).toList(),
      );
    }
  }

  Future<void> updateSignature(Signature updated) async {
    final signatures = await loadSignatures();
    final index = signatures.indexWhere((s) => s.id == updated.id);
    if (index >= 0) {
      signatures[index] = updated;
      await saveSignatures(signatures);
    }
  }
}
