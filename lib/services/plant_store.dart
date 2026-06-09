import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PlantStore {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  PlantStore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Future<void> saveHistory({
    required String scientificName,
    required double score,
    List<String>? commonNames,
    File? imageFile,
  }) async {
    final userId = await _ensureUserId();
    final imageUrl =
        imageFile == null ? null : await _tryUploadImage(userId, imageFile, 'history');

    await _firestore.collection('diagnosis_history').add({
      'userId': userId,
      'scientificName': scientificName,
      'score': score,
      'commonNames': commonNames ?? <String>[],
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveToMyPlants({
    required String scientificName,
    required double score,
    String? commonName,
    List<String>? commonNames,
    File? imageFile,
    String? referenceImageUrl,
    String? healthStatus,
  }) async {
    final userId = await _ensureUserId();
    final imageUrl =
        imageFile == null ? null : await _tryUploadImage(userId, imageFile, 'plants');
    final trimmedCommonName = commonName?.trim();
    final storedCommonName = (trimmedCommonName != null && trimmedCommonName.isNotEmpty)
        ? trimmedCommonName
        : null;

    await _firestore.collection('my_plants').add({
      'userId': userId,
      'commonName': storedCommonName,
      'scientificName': scientificName,
      'score': score,
      'commonNames': commonNames ?? <String>[],
      'imageUrl': imageUrl,
      'localImagePath': imageFile?.path,
      'referenceImageUrl': referenceImageUrl,
      'healthStatus': healthStatus ?? 'unknown',
      'createdAt': FieldValue.serverTimestamp(),
      'lastScannedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _ensureUserId() async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    if (user == null) {
      throw StateError('Anonymous sign-in failed.');
    }
    return user.uid;
  }

  Future<String?> _tryUploadImage(
    String userId,
    File imageFile,
    String folder,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('users/$userId/$folder/$timestamp.jpg');
      await ref.putFile(imageFile);
      return ref.getDownloadURL();
    } catch (_) {
      // Saving plants/history should still work even if Firebase Storage
      // isn't configured or image hosting is unavailable.
      return null;
    }
  }
}
