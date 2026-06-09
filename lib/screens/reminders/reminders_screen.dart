import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/app_header.dart';
import '../../services/auth_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
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
      appBar: const AppHeader(title: 'Reminders'),
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
                .collection('my_plants')
                .where('userId', isEqualTo: authSnapshot.data!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Failed to load reminders.'));
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
                      'No plants in your garden yet. Add plants to set up care reminders.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              final plantsNeedingCare = <Map<String, dynamic>>[];
              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final lastWatered = (data['lastWatered'] as Timestamp?)?.toDate();
                final plantName = data['commonName'] as String? ?? 
                                  (data['commonNames'] as List?)?.first ?? 
                                  'Unknown';
                
                if (lastWatered == null) {
                  plantsNeedingCare.add({
                    'docId': doc.id,
                    'plantName': plantName,
                    'lastWatered': lastWatered,
                    'needsWater': true,
                    'daysSince': null,
                  });
                } else {
                  final daysSince = DateTime.now().difference(lastWatered).inDays;
                  if (daysSince >= 3) {
                    plantsNeedingCare.add({
                      'docId': doc.id,
                      'plantName': plantName,
                      'lastWatered': lastWatered,
                      'needsWater': true,
                      'daysSince': daysSince,
                    });
                  }
                }
              }

              if (plantsNeedingCare.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF228B22)),
                        SizedBox(height: 16),
                        Text(
                          'All plants are happy!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF228B22)),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No plants need watering right now.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: plantsNeedingCare.length,
                itemBuilder: (context, index) {
                  final plant = plantsNeedingCare[index];
                  final docId = plant['docId'] as String;
                  final plantName = plant['plantName'] as String;
                  final daysSince = plant['daysSince'] as int?;

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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.water_drop, color: Color(0xFF228B22)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plantName,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                daysSince == null 
                                    ? 'Never watered' 
                                    : 'Last watered $daysSince days ago',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('my_plants')
                                .doc(docId)
                                .update({
                              'lastWatered': FieldValue.serverTimestamp(),
                              'healthStatus': 'healthy',
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$plantName watered ✓')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF228B22),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Water'),
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
