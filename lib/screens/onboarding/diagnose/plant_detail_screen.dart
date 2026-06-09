import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/diagnose_models.dart';

class PlantDetailScreen extends StatelessWidget {
  final DiagnosePlantCard plant;

  const PlantDetailScreen({Key? key, required this.plant}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plant.species.commonName, style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFF1D7A43),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'plant_image_${plant.query}',
              child: _buildImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.species.scientificName,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    plant.note,
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (plant.imageUrl == null || plant.imageUrl!.isEmpty) {
      return Container(
        height: 240,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F4E9), Color(0xFFD8EAD9)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.nature, size: 48, color: Color(0xFF2B7B45)),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: plant.imageUrl!.trim(),
      height: 240,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }
}
