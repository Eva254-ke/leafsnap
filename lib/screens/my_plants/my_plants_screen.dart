
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/app_header.dart';
import '../../components/remote_config_ui.dart';
import '../../models/garden_plant.dart';
import '../../services/auth_service.dart';
import '../../services/perenual_api.dart';
import '../../plant/plant_detail_screen.dart';
import '../onboarding/camera/camera_screen.dart';
import '../onboarding/search/search_screen.dart';
import '../reminders/reminders_screen.dart';
import '../wishlist/wishlist_screen.dart';

class MyPlantsScreen extends StatefulWidget {
  const MyPlantsScreen({super.key});

  @override
  State<MyPlantsScreen> createState() => _MyPlantsScreenState();
}

class _MyPlantsScreenState extends State<MyPlantsScreen> with SingleTickerProviderStateMixin {
  static const String _resolvedImageCacheKey = 'my_plants_resolved_images_v1';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Future<User> _authFuture;
  final PerenualApi _perenualApi = PerenualApi();
  final Map<String, String> _resolvedImageUrls = <String, String>{};
  final Set<String> _resolvingImageKeys = <String>{};
  String _searchQuery = '';
  bool _isSearching = false;

  // Fallback images for common plants (Unsplash - free to use)
  static const Map<String, String> _fallbackPlantImages = {
    'Tomato': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400&h=300&fit=crop',
    'Banana': 'https://images.unsplash.com/photo-1571771096344-2a5e0c3c2f8e?w=400&h=300&fit=crop',
    'Rose': 'https://images.unsplash.com/photo-1490750967868-58cb75069ed6?w=400&h=300&fit=crop',
    'Sunflower': 'https://images.unsplash.com/photo-1470509037663-253f1f5e7971?w=400&h=300&fit=crop',
    'Cactus': 'https://images.unsplash.com/photo-1459156212016-c812468e2115?w=400&h=300&fit=crop',
    'Fern': 'https://images.unsplash.com/photo-1598257006492-8f8cf9d3f8f0?w=400&h=300&fit=crop',
    'Orchid': 'https://images.unsplash.com/photo-1563240670-a7c7fac1b826?w=400&h=300&fit=crop',
    'Basil': 'https://images.unsplash.com/photo-1615485925694-a035a9e6c6c9?w=400&h=300&fit=crop',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _authFuture = AuthService().ensureSignedIn();
    _animationController.forward();
    _loadResolvedImageCache();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // PictureThis-style: Show two options when adding plant
  void _showAddPlantOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add a plant', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _addOptionCard(
                icon: Icons.camera_alt_outlined,
                title: 'Identify by picture',
                subtitle: 'Take or choose a photo',
                onTap: () {
                  Navigator.pop(context);
                  _addPlantByPicture();
                },
              ),
              const SizedBox(height: 12),
              _addOptionCard(
                icon: Icons.search_outlined,
                title: 'Search by name',
                subtitle: 'Find plants in our database',
                onTap: () {
                  Navigator.pop(context);
                  _addPlantByName();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF228B22), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF7A7A7A))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addPlantByPicture() async {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Camera'),
        builder: (context) => const CameraScreen(),
      ),
    );
  }

  Future<void> _addPlantByName() async {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Search'),
        builder: (context) => const SearchScreen(),
      ),
    );
  }

  String? _fallbackImageUrlForPlant(String plantName) {
    final normalized = plantName.trim().toLowerCase();
    for (final entry in _fallbackPlantImages.entries) {
      if (entry.key.toLowerCase() == normalized) return entry.value;
    }
    return null;
  }

  Future<void> _loadResolvedImageCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_resolvedImageCacheKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedImageUrls
          ..clear()
          ..addEntries(
            decoded.entries.map(
              (entry) => MapEntry(entry.key, entry.value.toString()),
            ),
          );
      });
    } catch (_) {
      // Ignore malformed cache and continue with live resolution.
    }
  }

  Future<void> _persistResolvedImageCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _resolvedImageCacheKey,
      jsonEncode(_resolvedImageUrls),
    );
  }

  String _imageCacheLookupKey({
    required String plantName,
    required String scientificName,
  }) {
    return '${plantName.trim().toLowerCase()}|${scientificName.trim().toLowerCase()}';
  }

  bool _hasUsableImageUrl(String? value) {
    final normalized = value?.trim();
    return normalized != null && normalized.isNotEmpty;
  }

  void _scheduleImageResolution({
    required String docId,
    required String plantName,
    required String scientificName,
    required String? currentImageUrl,
  }) {
    final cacheKey = _imageCacheLookupKey(
      plantName: plantName,
      scientificName: scientificName,
    );

    if (_hasUsableImageUrl(currentImageUrl) ||
        _hasUsableImageUrl(_resolvedImageUrls[cacheKey]) ||
        _resolvingImageKeys.contains(cacheKey)) {
      return;
    }

    Future<void>.microtask(
      () => _resolveImageForPlant(
        docId: docId,
        plantName: plantName,
        scientificName: scientificName,
        cacheKey: cacheKey,
      ),
    );
  }

  Future<void> _resolveImageForPlant({
    required String docId,
    required String plantName,
    required String scientificName,
    required String cacheKey,
  }) async {
    _resolvingImageKeys.add(cacheKey);

    try {
      final resolvedUrl = await _lookupPlantImage(
        plantName: plantName,
        scientificName: scientificName,
      );
      if (!_hasUsableImageUrl(resolvedUrl)) {
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedImageUrls[cacheKey] = resolvedUrl!.trim();
      });
      await _persistResolvedImageCache();

      await FirebaseFirestore.instance.collection('my_plants').doc(docId).set({
        'referenceImageUrl': resolvedUrl,
      }, SetOptions(merge: true));
    } catch (_) {
      // Keep the screen usable even when the API is rate-limited.
    } finally {
      _resolvingImageKeys.remove(cacheKey);
    }
  }

  Future<String?> _lookupPlantImage({
    required String plantName,
    required String scientificName,
  }) async {
    final queries = <String>[
      if (plantName.trim().isNotEmpty) plantName.trim(),
      if (scientificName.trim().isNotEmpty &&
          scientificName.trim().toLowerCase() != plantName.trim().toLowerCase())
        scientificName.trim(),
    ];

    final seen = <String>{};
    for (final query in queries) {
      final normalized = query.toLowerCase();
      if (!seen.add(normalized)) {
        continue;
      }

      final results = await _perenualApi.searchSpecies(query: query, page: 1);
      for (final result in results) {
        final candidate = result.imageUrl ?? result.thumbnailUrl;
        if (_hasUsableImageUrl(candidate)) {
          return candidate!.trim();
        }
      }
    }

    return _fallbackImageUrlForPlant(plantName);
  }

  int? _safeToInt(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return null;
    return value.toInt();
  }

  Widget _buildPlantImage({
    required String? imageUrl,
    required String? localImagePath,
    required String plantName,
    required double width,
    required double height,
  }) {
    final safeWidth = width.isFinite ? width : 140.0;
    final safeHeight = height.isFinite ? height : 110.0;
    final localImageFile = _localImageFile(localImagePath);
    if (localImageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          localImageFile,
          width: safeWidth,
          height: safeHeight,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _plantImagePlaceholder(plantName, safeWidth, safeHeight),
        ),
      );
    }

    final trimmedImageUrl = imageUrl?.trim();
    final resolvedUrl = (trimmedImageUrl != null && trimmedImageUrl.isNotEmpty)
        ? trimmedImageUrl
        : _fallbackImageUrlForPlant(plantName);
    if (resolvedUrl == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _plantImagePlaceholder(plantName, safeWidth, safeHeight),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: resolvedUrl,
        width: safeWidth,
        height: safeHeight,
        fit: BoxFit.cover,
        placeholder: (context, url) => _plantImagePlaceholder(plantName, safeWidth, safeHeight),
        errorWidget: (context, url, error) => _plantImagePlaceholder(plantName, safeWidth, safeHeight),
        memCacheWidth: _safeToInt(safeWidth),
        cacheKey: resolvedUrl,
      ),
    );
  }

  Widget _plantImagePlaceholder(String plantName, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: const Icon(Icons.local_florist, color: Color(0xFF228B22), size: 24),
    );
  }

  File? _localImageFile(String? path) {
    final trimmedPath = path?.trim();
    if (trimmedPath == null || trimmedPath.isEmpty) {
      return null;
    }

    final file = File(trimmedPath);
    if (!file.existsSync()) {
      return null;
    }
    return file;
  }

  String _displayNameForPlant(Map<String, dynamic> data) {
    final commonName = (data['commonName'] as String?)?.trim();
    if (commonName != null && commonName.isNotEmpty) {
      return commonName;
    }

    final commonNames = (data['commonNames'] as List<dynamic>? ?? const <dynamic>[])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (commonNames.isNotEmpty) {
      return commonNames.first;
    }

    final scientificName = (data['scientificName'] as String?)?.trim();
    if (scientificName != null && scientificName.isNotEmpty) {
      return scientificName;
    }

    return 'Unknown';
  }

  Color _healthColor(String status) {
    switch (status) {
      case 'healthy': return const Color(0xFF228B22);
      case 'needs_attention': return const Color(0xFFE67E22);
      case 'critical': return const Color(0xFFE74C3C);
      default: return const Color(0xFF95A5A6);
    }
  }

  String _healthLabel(String status) {
    switch (status) {
      case 'healthy': return 'Healthy';
      case 'needs_attention': return 'Needs care';
      case 'critical': return 'Urgent';
      default: return 'Unknown';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not watered';
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _waterPlant(String docId, String plantName) async {
    await FirebaseFirestore.instance.collection('my_plants').doc(docId).update({
      'lastWatered': FieldValue.serverTimestamp(),
      'healthStatus': 'healthy',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$plantName watered ✓'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _confirmDelete(String docId, String plantName) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove plant?'),
        content: Text('Remove "$plantName" from your garden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE74C3C)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await FirebaseFirestore.instance.collection('my_plants').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$plantName removed'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Widget _buildPlantCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = _displayNameForPlant(data);
    final scientificName = data['scientificName'] as String? ?? '';
    final score = (data['score'] as num?)?.toDouble() ?? 0;
    final confidence = '${(score * 100).toStringAsFixed(0)}%';
    final uploadedImageUrl = data['imageUrl'] as String?;
    final referenceImageUrl = data['referenceImageUrl'] as String?;
    final cacheKey = _imageCacheLookupKey(
      plantName: name,
      scientificName: scientificName,
    );
    final cachedResolvedImageUrl = _resolvedImageUrls[cacheKey];
    final imageUrl = (uploadedImageUrl != null && uploadedImageUrl.trim().isNotEmpty)
        ? uploadedImageUrl
        : (referenceImageUrl ?? cachedResolvedImageUrl);
    final localImagePath = data['localImagePath'] as String?;
    final healthStatus = data['healthStatus'] as String? ?? 'unknown';
    final lastWatered = (data['lastWatered'] as Timestamp?)?.toDate();
    final docId = doc.id;

    if (_localImageFile(localImagePath) == null) {
      _scheduleImageResolution(
        docId: docId,
        plantName: name,
        scientificName: scientificName,
        currentImageUrl: imageUrl,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'Plant Detail'),
                builder: (context) => PlantDetailScreen(
                  plant: GardenPlant(
                    id: docId,
                    name: name,
                    scientificName: scientificName,
                    imageUrl: imageUrl,
                    localImagePath: localImagePath,
                    dateAdded: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                    lastWatered: lastWatered,
                    healthStatus: healthStatus,
                  ),
                ),
              ),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildPlantImage(
                  imageUrl: imageUrl,
                  localImagePath: localImagePath,
                  plantName: name,
                  width: double.infinity,
                  height: 100,
                ),
                // Health status badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _healthColor(healthStatus).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _healthLabel(healthStatus),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF1B1B1B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(lastWatered),
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF7A7A7A)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _quickActionIcon(
                          icon: Icons.water_drop_outlined,
                          label: 'Water',
                          onTap: () => _waterPlant(docId, name),
                        ),
                        const SizedBox(width: 16),
                        _quickActionIcon(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          onTap: () {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Edit coming soon')),
                              );
                            }
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFB0B0B0), size: 18),
                          onPressed: () => _confirmDelete(docId, name),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionIcon({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF228B22), size: 16),
            const SizedBox(height: 1),
            Text(label, style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF228B22))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RemoteConfigBuilder(
      screenId: RemoteConfigScreens.myPlants,
      fallbackBackgroundColor: const Color(0xFFF0FFF4),
      fallbackPrimaryColor: const Color(0xFF228B22),
      builder: (context, remoteConfig) {
        return Scaffold(
      backgroundColor: remoteConfig.backgroundColor,
      appBar: AppHeader(
        title: 'My Garden',
        leftActions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_outlined, color: const Color(0xFF228B22)),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              });
            },
          ),
        ],
        rightActions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF228B22)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'Reminders'),
                  builder: (_) => const RemindersScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Color(0xFF228B22)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'Wishlist'),
                  builder: (_) => const WishlistScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          bottom: true,
          child: Column(
            children: [
              if (remoteConfig.banner != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: RemoteScreenBanner(
                    banner: remoteConfig.banner!,
                    primaryColor: remoteConfig.primaryColor,
                  ),
                ),
              // Inline search bar when active
              if (_isSearching)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search your plants...',
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF228B22), size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          style: GoogleFonts.inter(fontSize: 14),
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _isSearching = false;
                          });
                          FocusScope.of(context).unfocus();
                        },
                        child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF228B22))),
                      ),
                    ],
                  ),
              ),
              // Plant grid or empty state
              Expanded(
                child: FutureBuilder<User>(
                  future: _authFuture,
                  builder: (context, authSnapshot) {
                    if (authSnapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF228B22)),
                      );
                    }

                    if (authSnapshot.hasError || authSnapshot.data == null) {
                      return _buildEmptyState();
                    }

                    final user = authSnapshot.data!;
                    final query = FirebaseFirestore.instance
                        .collection('my_plants')
                        .where('userId', isEqualTo: user.uid)
                        .orderBy('createdAt', descending: true);

                    return StreamBuilder<QuerySnapshot>(
                      stream: query.snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _buildEmptyState();
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFF228B22)),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        final filteredDocs = _searchQuery.isEmpty
                            ? docs
                            : docs.where((doc) {
                                 final data = doc.data() as Map<String, dynamic>;
                                final plantName =
                                    _displayNameForPlant(data).toLowerCase();
                                return plantName.contains(
                                  _searchQuery.toLowerCase(),
                                );
                              }).toList();

                        if (filteredDocs.isEmpty) {
                          return _buildEmptyState();
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) => _buildPlantCard(filteredDocs[index]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  bool _isPermissionDenied(Object? error) {
    return error is FirebaseException && error.code == 'permission-denied';
  }

  String _plantsErrorMessage(Object? error) {
    return 'Failed to load plants.';
  }

  Widget _buildLoadError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: Color(0xFF95A5A6), size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF7A7A7A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildLeafBadge(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plant Finder',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1B1B1B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose the perfect plants for you!',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF7A7A7A)),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _showAddPlantOptions,
                      child: Text(
                        'Get Started',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF228B22)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildEmptyIllustration(),
              const SizedBox(height: 20),
              Text(
                'No plants added',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1B1B1B)),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your entire plant family, view care tips and track your plants\' growth here',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7A7A7A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showAddPlantOptions,
                  icon: const Icon(Icons.add, size: 20),
                  label: Text('Add Plant', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF228B22),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeafBadge() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFE9F6EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(34, 34),
          painter: _LeafBadgePainter(),
        ),
      ),
    );
  }

  Widget _buildEmptyIllustration() {
    return SizedBox(
      width: 170,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 8,
            child: Container(
              width: 130,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(color: const Color(0xFF228B22), width: 1),
              ),
            ),
          ),
          Positioned(
            bottom: 38,
            child: _emptyCard(width: 70, height: 48, showCheck: true),
          ),
          Positioned(
            bottom: 46,
            left: 40,
            child: Transform.rotate(
              angle: -0.2,
              child: _emptyCard(width: 60, height: 40),
            ),
          ),
          Positioned(
            bottom: 50,
            right: 40,
            child: Transform.rotate(
              angle: 0.18,
              child: _emptyCard(width: 60, height: 40),
            ),
          ),
          Positioned(
            top: 18,
            right: 32,
            child: Column(
              children: [
                _accentBar(16),
                const SizedBox(height: 6),
                _accentBar(10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accentBar(double width) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF228B22),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _emptyCard({required double width, required double height, bool showCheck = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB0B0B0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: showCheck
          ? Center(
              child: CustomPaint(
                size: const Size(20, 14),
                painter: _CheckPainter(),
              ),
            )
          : null,
    );
  }
}

class _LeafBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0xFF228B22);
    final light = Paint()..color = const Color(0xFF2ECC71);
    final stem = Paint()
      ..color = const Color(0xFF1E7E34)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leftLeaf = Rect.fromCenter(
      center: Offset(size.width * 0.42, size.height * 0.42),
      width: size.width * 0.38,
      height: size.height * 0.24,
    );
    final rightLeaf = Rect.fromCenter(
      center: Offset(size.width * 0.6, size.height * 0.5),
      width: size.width * 0.32,
      height: size.height * 0.2,
    );

    canvas.drawOval(leftLeaf, dark);
    canvas.drawOval(rightLeaf, light);
    canvas.drawLine(
      Offset(size.width * 0.52, size.height * 0.62),
      Offset(size.width * 0.52, size.height * 0.78),
      stem,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF228B22)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.55)
      ..lineTo(size.width * 0.45, size.height * 0.85)
      ..lineTo(size.width * 0.9, size.height * 0.15);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}