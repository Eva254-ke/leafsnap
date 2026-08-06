// Load environment variables from the parent .env file (two levels up)
require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });

const express = require('express');
const neo4j = require('neo4j-driver');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Verify environment variables are loaded
if (!process.env.NEO4J_URI || !process.env.NEO4J_USER || !process.env.NEO4J_PASSWORD) {
  console.error('[ERROR] Neo4j credentials not found. Check your .env file.');
  console.error('[DEBUG] NEO4J_URI:', process.env.NEO4J_URI);
  console.error('[DEBUG] NEO4J_USER:', process.env.NEO4J_USER);
  process.exit(1);
}

// Neo4j connection
const driver = neo4j.driver(
  process.env.NEO4J_URI,
  neo4j.auth.basic(process.env.NEO4J_USER, process.env.NEO4J_PASSWORD)
);

console.log('[INFO] Connected to Neo4j at:', process.env.NEO4J_URI);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'LeafSnap Care API is running',
    timestamp: new Date().toISOString()
  });
});

// Get care tips for a species
app.post('/api/care-tips', async (req, res) => {
  const { species_id, disease_id, latitude, user_id } = req.body;

  if (!species_id) {
    return res.status(400).json({ error: 'species_id is required' });
  }

  const session = driver.session();

  try {
    const tips = [];

    // 1. If disease detected, get disease-specific treatment tips
    if (disease_id) {
      const diseaseResult = await session.run(
        `
        MATCH (d:Disease {id: $diseaseId})
        RETURN d
        `,
        { diseaseId: disease_id }
      );

      if (diseaseResult.records.length > 0) {
        const disease = diseaseResult.records[0].get('d').properties;
        const seasonTips = JSON.parse(disease.season_tips);
        const currentSeason = getCurrentSeason(latitude);

        tips.push({
          category: 'disease_treatment',
          title: `Treat ${disease.name}`,
          description: disease.organic_treatment,
          urgency: 'urgent',
          season: currentSeason,
          icon_key: 'disease_treatment',
          detailed_info: {
            organic: disease.organic_treatment,
            chemical: disease.chemical_treatment,
            prevention: disease.prevention,
            season_specific: seasonTips[currentSeason] || null
          }
        });
      }
    }

    // 2. Get general care requirements for the species
    const careResult = await session.run(
      `
      MATCH (s:Species {id: $speciesId})-[:NEEDS]->(c:CareRequirement)
      RETURN c
      `,
      { speciesId: species_id }
    );

    const currentSeason = getCurrentSeason(latitude);

    for (const record of careResult.records) {
      const care = record.get('c').properties;
      const seasonAdjustments = JSON.parse(care.season_adjustments);

      tips.push({
        category: care.category,
        title: care.title,
        description: care.description,
        urgency: 'general',
        season: currentSeason,
        icon_key: care.category,
        detailed_info: {
          frequency: care.frequency,
          season_adjustment: seasonAdjustments[currentSeason] || null
        }
      });
    }

    // 3. Limit to 5 tips, prioritized by urgency
    const prioritizedTips = tips.sort((a, b) => {
      const urgencyOrder = { urgent: 1, seasonal: 2, general: 3 };
      return urgencyOrder[a.urgency] - urgencyOrder[b.urgency];
    }).slice(0, 5);

    res.json({
      success: true,
      species_id: species_id,
      disease_id: disease_id || null,
      season: currentSeason,
      tips: prioritizedTips
    });

  } catch (error) {
    console.error('[ERROR]', error);
    res.status(500).json({ error: 'Failed to fetch care tips' });
  } finally {
    await session.close();
  }
});

// Get all diseases for a species
app.get('/api/diseases/:speciesId', async (req, res) => {
  const { speciesId } = req.params;
  const session = driver.session();

  try {
    const result = await session.run(
      `
      MATCH (s:Species {id: $speciesId})-[:SUSCEPTIBLE_TO]->(d:Disease)
      RETURN d
      `,
      { speciesId }
    );

    const diseases = result.records.map(record => {
      const disease = record.get('d').properties;
      return {
        id: disease.id,
        name: disease.name,
        organic_treatment: disease.organic_treatment,
        chemical_treatment: disease.chemical_treatment,
        prevention: disease.prevention
      };
    });

    res.json({
      success: true,
      species_id: speciesId,
      diseases: diseases
    });

  } catch (error) {
    console.error('[ERROR]', error);
    res.status(500).json({ error: 'Failed to fetch diseases' });
  } finally {
    await session.close();
  }
});

// Get all species with care tips
app.get('/api/species', async (req, res) => {
  const session = driver.session();

  try {
    const result = await session.run(
      `
      MATCH (s:Species)
      RETURN s
      `
    );

    const species = result.records.map(record => {
      const s = record.get('s').properties;
      return {
        id: s.id,
        common_name: s.common_name || s.id,
        regions: s.regions,
        hardiness_zones: s.hardiness_zones
      };
    });

    res.json({
      success: true,
      count: species.length,
      species: species
    });

  } catch (error) {
    console.error('[ERROR]', error);
    res.status(500).json({ error: 'Failed to fetch species' });
  } finally {
    await session.close();
  }
});

// Helper function to determine current season based on latitude
function getCurrentSeason(latitude) {
  const month = new Date().getMonth() + 1; // 1-12
  
  // Default to northern hemisphere if latitude not provided
  if (latitude === undefined || latitude === null) {
    latitude = 40.0; // Default to US latitude
  }
  
  // Northern hemisphere (latitude >= 0)
  if (latitude >= 0) {
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'fall';
    return 'winter';
  }
  
  // Southern hemisphere (latitude < 0) - flip seasons
  if (month >= 3 && month <= 5) return 'fall';
  if (month >= 6 && month <= 8) return 'winter';
  if (month >= 9 && month <= 11) return 'spring';
  return 'summer';
}

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`[INFO] LeafSnap Care API running on port ${PORT}`);
  console.log(`[INFO] Health check: http://localhost:${PORT}/health`);
  console.log(`[INFO] API endpoint: POST http://localhost:${PORT}/api/care-tips`);
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n[INFO] Shutting down gracefully...');
  await driver.close();
  process.exit(0);
});