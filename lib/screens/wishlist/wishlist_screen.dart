import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/app_header.dart';
import '../../services/auth_service.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late Future<User> _authFuture;

  @override
  void initState() {
    super.initState();
    _authFuture = AuthService().ensureSignedIn();
  }

  Future<void> _removeFromWishlist(String docId, String plantName) async {
    await FirebaseFirestore.instance.collection('wishlist').doc(docId).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$plantName removed from wishlist')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: const AppHeader(title: 'Wishlist'),
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
                .collection('wishlist')
                .where('userId', isEqualTo: authSnapshot.data!.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Failed to load wishlist.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 64, color: Color(0xFFE57373)),
                        SizedBox(height: 16),
                        Text(
                          'Your wishlist is empty',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFE57373)),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Save plants you want to add to your garden here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final plantName = data['plantName'] as String? ?? 'Unknown';
                  final scientificName = data['scientificName'] as String? ?? '';
                  final imageUrl = data['imageUrl'] as String?;
                  final docId = docs[index].id;

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
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                            ),
                          )
                        else
                          _buildPlaceholder(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plantName,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              if (scientificName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  scientificName,
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFE57373)),
                          onPressed: () => _removeFromWishlist(docId, plantName),
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

  Widget _buildPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.local_florist, color: Color(0xFFE57373)),
    );
  }
}
