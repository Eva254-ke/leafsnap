import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../components/app_header.dart';
import '../../../services/auth_service.dart';

class DiagnoseHistoryScreen extends StatefulWidget {
  const DiagnoseHistoryScreen({super.key});

  @override
  State<DiagnoseHistoryScreen> createState() => _DiagnoseHistoryScreenState();
}

class _DiagnoseHistoryScreenState extends State<DiagnoseHistoryScreen> {
  late Future<User> _authFuture;

  @override
  void initState() {
    super.initState();
    _authFuture = AuthService().ensureSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      appBar: const AppHeader(title: 'History'),
      body: FutureBuilder<User>(
        future: _authFuture,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (authSnapshot.hasError || authSnapshot.data == null) {
            return const Center(child: Text('Could not sign in anonymously.'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('diagnosis_history')
                .where('userId', isEqualTo: authSnapshot.data!.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                if (error is FirebaseException) {
                  if (error.code == 'permission-denied') {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'History access is currently unavailable. Please try again later.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load history: ${error.message}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Failed to load history. Please check your connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No diagnosis history yet. Start diagnosing plants to see your history here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['scientificName'] as String? ?? 'Unknown';
                  final score = (data['score'] as num?)?.toDouble() ?? 0;
                  final imageUrl = data['imageUrl'] as String?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          const Icon(
                            Icons.local_florist,
                            color: Color(0xFF228B22),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${(score * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Color(0xFF228B22),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
