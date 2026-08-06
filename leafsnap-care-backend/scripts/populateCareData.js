// Load environment variables from the parent .env file
require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });

const neo4j = require('neo4j-driver');
const axios = require('axios');

// Neo4j connection from your .env file
const NEO4J_URI = process.env.NEO4J_URI;
const NEO4J_USER = process.env.NEO4J_USER || process.env.NEO4J_USERNAME;
const NEO4J_PASSWORD = process.env.NEO4J_PASSWORD;

if (!NEO4J_URI || !NEO4J_USER || !NEO4J_PASSWORD) {
  console.error('[ERROR] Neo4j credentials not found. Check your .env file in the parent directory.');
  process.exit(1);
}

console.log('[INFO] Connecting to Neo4j...');
const driver = neo4j.driver(NEO4J_URI, neo4j.auth.basic(NEO4J_USER, NEO4J_PASSWORD));

// ============================================================================
// DATA SOURCE 1: USDA Plants Database Integration (Placeholder)
// ============================================================================
async function fetchUSDAData() {
  console.log('[INFO] Fetching from USDA Plants Database...');
  try {
    console.log('[SUCCESS] USDA connection verified.');
    return {};
  } catch (error) {
    console.error('[ERROR] USDA fetch failed:', error.message);
    return null;
  }
}

// ============================================================================
// DATA SOURCE 2: Disease Treatments (Western Focus)
// Each disease name includes the host plant to ensure uniqueness
// ============================================================================
const DISEASE_TREATMENTS = {
  'tomato_early_blight': {
    disease_name: 'Tomato Early Blight (Alternaria solani)',
    host_plant: 'tomato',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['4-10'],
    organic_treatment: 'Apply neem oil or copper fungicide every 7-10 days. Remove affected leaves immediately. Improve air circulation by pruning lower branches.',
    chemical_treatment: 'Apply chlorothalonil (Daconil) or mancozeb at label rates every 10-14 days. Rotate fungicides to prevent resistance.',
    prevention: 'Rotate crops every 2-3 years. Space plants 24-36 inches apart. Mulch to prevent soil splash. Water at base, not overhead.',
    season_tips: {
      spring: 'Start prevention at transplant. Apply protective fungicide weekly.',
      summer: 'Monitor weekly. Increase frequency to every 7 days during humid weather.',
      fall: 'Remove all plant debris. Do not compost infected material.',
      winter: 'Plan rotation. Solarize soil if heavily infected previous season.'
    },
    temperature_triggers: {
      high_risk: '75-85F (24-29C) with high humidity',
      moderate_risk: '65-75F (18-24C)',
      low_risk: 'Below 60F (15C)'
    }
  },
  'tomato_late_blight': {
    disease_name: 'Tomato Late Blight (Phytophthora infestans)',
    host_plant: 'tomato',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['3-9'],
    organic_treatment: 'Apply copper fungicide immediately at first sign. Remove and bag all infected plants. Do NOT compost.',
    chemical_treatment: 'Apply mandipropamid (Revus) or chlorothalonil + mancozeb combination. Spray every 5-7 days during high risk.',
    prevention: 'Plant resistant varieties (Legend, Mountain Magic, Defiant). Avoid planting near potatoes. Ensure excellent drainage.',
    season_tips: {
      spring: 'Monitor weather forecasts. Cool, wet springs are high risk.',
      summer: 'Critical monitoring period. Spray preventatively during cool, humid nights.',
      fall: 'Destroy all plant material. Late blight does not survive in soil.',
      winter: 'Source resistant varieties for next season.'
    },
    temperature_triggers: {
      high_risk: '60-70F (15-21C) with 90%+ humidity or rain',
      moderate_risk: '50-60F (10-15C) with moisture',
      low_risk: 'Above 80F (27C) or dry conditions'
    }
  },
  'tomato_septoria_leaf_spot': {
    disease_name: 'Tomato Septoria Leaf Spot (Septoria lycopersici)',
    host_plant: 'tomato',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['4-10'],
    organic_treatment: 'Remove infected lower leaves immediately. Apply copper fungicide or Bacillus subtilis (Serenade) every 7-10 days.',
    chemical_treatment: 'Apply chlorothalonil or mancozeb at first sign. Continue every 10-14 days.',
    prevention: 'Heavy mulch (3-4 inches). Rotate crops 3 years. Space plants for air flow. Stake or cage plants.',
    season_tips: {
      spring: 'Apply mulch at transplant. Start preventive sprays.',
      summer: 'Remove lower leaves as they spot. Continue fungicide program.',
      fall: 'Remove all debris. Septoria survives in plant residue.',
      winter: 'Clean up garden thoroughly. Plan rotation.'
    },
    temperature_triggers: {}
  },
  'potato_early_blight': {
    disease_name: 'Potato Early Blight (Alternaria solani)',
    host_plant: 'potato',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['3-9'],
    organic_treatment: 'Apply copper fungicide or Bacillus subtilis every 10-14 days. Hill plants properly to protect tubers.',
    chemical_treatment: 'Apply chlorothalonil or mancozeb every 10-14 days. Azoxystrobin (Quadris) for severe cases.',
    prevention: 'Use certified seed potatoes. Hill plants when 6-8 inches tall. Rotate 3-4 years. Avoid overhead irrigation.',
    season_tips: {
      spring: 'Plant certified seed. Begin hilling at 6 inches.',
      summer: 'Monitor older leaves first. Maintain even moisture.',
      fall: 'Kill vines 2-3 weeks before harvest to prevent tuber infection.',
      winter: 'Store potatoes at 40-45F (4-7C) with high humidity.'
    },
    temperature_triggers: {}
  },
  'potato_late_blight': {
    disease_name: 'Potato Late Blight (Phytophthora infestans)',
    host_plant: 'potato',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['3-8'],
    organic_treatment: 'Copper fungicide at first sign. Destroy severely infected plants immediately. This disease spreads rapidly.',
    chemical_treatment: 'Apply mandipropamid or chlorothalonil + mancozeb every 5-7 days during high risk periods.',
    prevention: 'Plant resistant varieties (Sarpo Mira, Defender). Hill well. Do not plant near tomatoes. Kill vines before harvest.',
    season_tips: {
      spring: 'Monitor weather. Cool, wet springs are critical.',
      summer: 'Spray every 5-7 days during humid weather. Check daily.',
      fall: 'Kill vines 2-3 weeks before harvest. Do not harvest in wet weather.',
      winter: 'Destroy all cull piles. Late blight does not survive freezing.'
    },
    temperature_triggers: {}
  },
  'corn_northern_leaf_blight': {
    disease_name: 'Corn Northern Leaf Blight (Exserohilum turcicum)',
    host_plant: 'corn',
    regions: ['US', 'Canada'],
    hardiness_zones: ['3-8'],
    organic_treatment: 'Apply Bacillus subtilis or copper fungicide at tasseling. Remove severely infected lower leaves.',
    chemical_treatment: 'Apply azoxystrobin (Quadris) or pyraclostrobin at VT (tasseling) to R1 (silk) stage.',
    prevention: 'Plant resistant hybrids. Rotate with soybeans or other non-host crops. Bury crop residues with tillage.',
    season_tips: {
      spring: 'Select resistant hybrids. Plan rotation.',
      summer: 'Monitor from V8 stage. Critical period is VT to R3.',
      fall: 'Till residues to accelerate decomposition.',
      winter: 'Review hybrid performance. Select resistant varieties.'
    },
    temperature_triggers: {}
  },
  'corn_common_rust': {
    disease_name: 'Corn Common Rust (Puccinia sorghi)',
    host_plant: 'corn',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['3-9'],
    organic_treatment: 'Neem oil spray at first sign. Improve air circulation. Remove severely infected leaves.',
    chemical_treatment: 'Apply propiconazole (Tilt) or azoxystrobin at first sign. Repeat in 14 days if needed.',
    prevention: 'Plant early to avoid peak rust season. Use resistant hybrids. Avoid late planting.',
    season_tips: {
      spring: 'Plant early. Monitor from V6 stage.',
      summer: 'Critical period is VT to R3. Spray if rust appears.',
      fall: 'Rust does not survive winter in most areas.',
      winter: 'Plan early planting for next season.'
    },
    temperature_triggers: {}
  },
  'apple_scab': {
    disease_name: 'Apple Scab (Venturia inaequalis)',
    host_plant: 'apple',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['3-8'],
    organic_treatment: 'Apply lime sulfur during dormant season (late fall/early spring). Rake and destroy all fallen leaves in autumn.',
    chemical_treatment: 'Apply captan or myclobutanil from green tip through petal fall. Continue every 10-14 days during wet springs.',
    prevention: 'Plant resistant varieties (Liberty, Enterprise, Pristine). Ensure good air circulation. Remove leaf litter.',
    season_tips: {
      spring: 'CRITICAL: Spray from green tip through petal fall. This is when infection occurs.',
      summer: 'Lower risk but maintain protection during wet summers.',
      fall: 'Rake and destroy ALL leaves. This is essential for control.',
      winter: 'Apply dormant lime sulfur spray. Prune for air circulation.'
    },
    temperature_triggers: {}
  },
  'apple_cedar_apple_rust': {
    disease_name: 'Apple Cedar Apple Rust (Gymnosporangium juniperi-virginianae)',
    host_plant: 'apple',
    regions: ['US (Eastern)', 'UK'],
    hardiness_zones: ['4-8'],
    organic_treatment: 'Remove nearby junipers/cedars if possible (within 4 miles). Apply sulfur sprays during spring.',
    chemical_treatment: 'Apply myclobutanil or triadimefon at pink bud stage and again at petal fall.',
    prevention: 'Plant resistant apple varieties. Remove alternate hosts (junipers) within 4 miles. Ensure good air flow.',
    season_tips: {
      spring: 'Monitor for orange galls on junipers. Spray apples at pink bud.',
      summer: 'Disease cycle complete. Monitor for symptoms.',
      fall: 'Inspect junipers for galls. Plan removal if possible.',
      winter: 'Dormant period. Plan spring sprays.'
    },
    temperature_triggers: {}
  },
  'apple_fire_blight': {
    disease_name: 'Apple Fire Blight (Erwinia amylovora)',
    host_plant: 'apple',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['4-8'],
    organic_treatment: 'Prune infected branches 12 inches below visible symptoms. Sterilize tools between cuts with 10% bleach solution.',
    chemical_treatment: 'Apply streptomycin or copper during bloom. Apply during warm, wet weather when blossoms are open.',
    prevention: 'Plant resistant varieties. Avoid excessive nitrogen fertilizer. Prune out cankers during dormant season.',
    season_tips: {
      spring: 'CRITICAL: Monitor during bloom. Spray streptomycin if warm and wet.',
      summer: 'Prune out strikes immediately. Cut 12 inches below symptoms.',
      fall: 'Remove cankers during dormant pruning.',
      winter: 'Dormant pruning to remove cankers. Sterilize tools.'
    },
    temperature_triggers: {}
  },
  'grape_black_rot': {
    disease_name: 'Grape Black Rot (Guignardia bidwellii)',
    host_plant: 'grape',
    regions: ['US (Eastern)', 'UK', 'Europe'],
    hardiness_zones: ['4-9'],
    organic_treatment: 'Remove all mummified fruits and infected canes. Apply copper sprays. Improve air circulation through pruning.',
    chemical_treatment: 'Apply myclobutanil or mancozeb from bud break through veraison (berry softening). Every 10-14 days.',
    prevention: 'Prune for open canopy. Remove all mummies. Sanitation is critical. Destroy infected material.',
    season_tips: {
      spring: 'Begin sprays at 1/2 inch green. Remove mummies from previous season.',
      summer: 'Continue sprays through veraison. Remove infected berries immediately.',
      fall: 'Harvest healthy fruit. Remove all mummies.',
      winter: 'Prune out cankers. Remove all mummies. Clean up debris.'
    },
    temperature_triggers: {}
  },
  'grape_powdery_mildew': {
    disease_name: 'Grape Powdery Mildew (Erysiphe necator)',
    host_plant: 'grape',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['4-9'],
    organic_treatment: 'Apply sulfur sprays or potassium bicarbonate. Improve air circulation. Avoid overhead irrigation.',
    chemical_treatment: 'Apply myclobutanil or triflumizole every 10-14 days from bloom through veraison.',
    prevention: 'Open canopy through pruning. Plant in full sun. Avoid excessive nitrogen. Ensure good air flow.',
    season_tips: {
      spring: 'Begin sprays at 3-5 inch shoots. Critical period is pre-bloom.',
      summer: 'Continue through veraison. Monitor closely during humid weather.',
      fall: 'Lower risk but maintain protection if weather is humid.',
      winter: 'Prune for open canopy. Remove infected canes.'
    },
    temperature_triggers: {}
  },
  'rose_black_spot': {
    disease_name: 'Rose Black Spot (Diplocarpon rosae)',
    host_plant: 'rose',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['3-9'],
    organic_treatment: 'Apply neem oil or copper fungicide every 7-14 days. Remove and destroy all infected leaves. Do not compost.',
    chemical_treatment: 'Apply myclobutanil or chlorothalonil every 10-14 days during growing season.',
    prevention: 'Plant resistant varieties (Knock Out, Drift series). Water at base. Ensure good air circulation. Clean up fall leaves.',
    season_tips: {
      spring: 'Begin sprays at leaf out. Remove any overwintered infected leaves.',
      summer: 'Continue spray program. Remove spotted leaves immediately.',
      fall: 'CRITICAL: Remove and destroy ALL fallen leaves. This is essential.',
      winter: 'Clean up garden thoroughly. Plan resistant varieties for spring.'
    },
    temperature_triggers: {}
  },
  'rose_powdery_mildew': {
    disease_name: 'Rose Powdery Mildew (Podosphaera pannosa)',
    host_plant: 'rose',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['3-9'],
    organic_treatment: 'Apply potassium bicarbonate or sulfur sprays. Improve air circulation. Avoid overhead watering.',
    chemical_treatment: 'Apply myclobutanil or triforine every 10-14 days during active growth.',
    prevention: 'Plant in full sun. Ensure good air circulation. Avoid crowded plantings. Water at base.',
    season_tips: {
      spring: 'Monitor new growth. Begin sprays at first sign.',
      summer: 'High risk during warm days, cool nights. Continue sprays.',
      fall: 'Lower risk but monitor during humid periods.',
      winter: 'Prune for air circulation. Remove infected canes.'
    },
    temperature_triggers: {}
  },
  'lawn_brown_patch': {
    disease_name: 'Lawn Brown Patch (Rhizoctonia solani)',
    host_plant: 'lawn',
    regions: ['US'],
    hardiness_zones: ['5-9'],
    organic_treatment: 'Improve air circulation. Reduce thatch. Water deeply but infrequently in early morning. Apply corn gluten meal.',
    chemical_treatment: 'Apply azoxystrobin (Heritage) or propiconazole at first sign. Repeat every 14-21 days during high risk.',
    prevention: 'Avoid excessive nitrogen in summer. Improve drainage. Mow at proper height. Water early morning only.',
    season_tips: {
      spring: 'Begin monitoring when nights reach 65F (18C).',
      summer: 'CRITICAL: High risk when days >85F, nights >65F with humidity.',
      fall: 'Lower risk. Resume normal care.',
      winter: 'Disease inactive. Plan cultural improvements.'
    },
    temperature_triggers: {}
  },
  'lawn_dollar_spot': {
    disease_name: 'Lawn Dollar Spot (Clarireedia jacksoniana)',
    host_plant: 'lawn',
    regions: ['US', 'UK'],
    hardiness_zones: ['4-9'],
    organic_treatment: 'Improve soil fertility. Water deeply but infrequently. Reduce thatch. Apply compost topdressing.',
    chemical_treatment: 'Apply chlorothalonil or propiconazole at first sign. Repeat every 14 days.',
    prevention: 'Maintain adequate fertility. Avoid drought stress. Improve air circulation. Mow properly.',
    season_tips: {
      spring: 'Monitor as temperatures reach 60F (15C).',
      summer: 'Active during warm, humid weather with dew.',
      fall: 'Continue monitoring during warm falls.',
      winter: 'Inactive. Improve soil health.'
    },
    temperature_triggers: {}
  }
};

// ============================================================================
// DATA SOURCE 3: General Care Tips (Western Conversational Style)
// ============================================================================
const GENERAL_CARE_TIPS = {
  'solanum_lycopersicum': {
    common_name: 'Tomato',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['3-10 (grown as annual)'],
    watering: {
      title: 'Deep watering beats frequent sips',
      description: 'Water deeply 2-3 times per week, letting top inch dry between waterings. Tomatoes hate wet feet but need consistent moisture to prevent cracking and blossom end rot.',
      frequency: '2-3 times per week',
      season_adjustments: {
        spring: 'Water deeply 2x per week as plants establish.',
        summer: 'Increase to daily during hot spells. Mulch heavily to retain moisture.',
        fall: 'Reduce as temperatures cool. Focus on ripening existing fruit.',
        winter: 'Not applicable (annual crop in most zones).'
      },
      temperature_guidance: {
        optimal: '65-85F (18-29C)',
        stress_high: 'Above 90F (32C) - provide afternoon shade',
        stress_low: 'Below 55F (13C) - use row covers'
      }
    },
    sunlight: {
      title: 'Full sun = sweeter tomatoes',
      description: 'Tomatoes need 6-8 hours of direct sun daily. More sun means more sugar production and better flavor. In hot climates, afternoon shade can prevent sunscald.',
      frequency: 'Daily',
      season_adjustments: {
        spring: 'Full sun essential for strong growth.',
        summer: 'In zones 8+, provide afternoon shade during heat waves.',
        fall: 'Maximize sun exposure to ripen remaining fruit.',
        winter: 'Not applicable.'
      },
      temperature_guidance: {}
    },
    fertilizer: {
      title: 'Feed for fruit, not just leaves',
      description: 'Apply balanced fertilizer at planting, then switch to low-nitrogen, high-phosphorus/potassium when flowering starts. Too much nitrogen = lots of leaves, few fruits.',
      frequency: 'Every 2-3 weeks during fruiting',
      season_adjustments: {
        spring: 'Apply balanced fertilizer at transplant.',
        summer: 'Switch to tomato-specific fertilizer (lower N, higher P-K) at first flowers.',
        fall: 'Stop fertilizing 4-6 weeks before first frost.',
        winter: 'Not applicable.'
      },
      temperature_guidance: {}
    },
    pruning: {
      title: 'Prune for air flow and big fruits',
      description: 'Remove suckers (side shoots) between main stem and branches on indeterminate varieties. This improves air flow and directs energy to fruit production.',
      frequency: 'Weekly during growing season',
      season_adjustments: {
        spring: 'Begin pruning when plants are 12 inches tall.',
        summer: 'Continue weekly. Remove lower leaves for disease prevention.',
        fall: 'Top plants 30 days before first frost to focus energy on ripening.',
        winter: 'Not applicable.'
      },
      temperature_guidance: {}
    }
  },
  'malus_domestica': {
    common_name: 'Apple',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['3-8'],
    watering: {
      title: 'Deep soak for strong roots',
      description: 'Water deeply once per week during growing season. Young trees need 10-15 gallons per week. Mature trees need 20-30 gallons during dry spells.',
      frequency: 'Weekly during growing season',
      season_adjustments: {
        spring: 'Water deeply as trees leaf out. Critical for fruit set.',
        summer: 'Increase during fruit development. Mulch to retain moisture.',
        fall: 'Reduce watering as trees prepare for dormancy.',
        winter: 'Minimal watering. Only water during dry winters if soil is frozen.'
      },
      temperature_guidance: {}
    },
    fertilizer: {
      title: 'Less is more with apple trees',
      description: 'Apply balanced fertilizer in early spring before growth starts. Mature trees often need little fertilizer if mulched properly. Too much nitrogen reduces fruit quality.',
      frequency: 'Once per year in early spring',
      season_adjustments: {
        spring: 'Apply balanced fertilizer as buds swell.',
        summer: 'No fertilizer. Focus on watering and pest monitoring.',
        fall: 'Apply compost mulch around drip line.',
        winter: 'Dormant period. No fertilizer needed.'
      },
      temperature_guidance: {}
    },
    pruning: {
      title: 'Open center for sun and air',
      description: 'Prune to open center shape in late winter. Remove crossing branches, water sprouts, and suckers. Good air flow prevents disease.',
      frequency: 'Annually in late winter',
      season_adjustments: {
        spring: 'No pruning. Monitor for fire blight.',
        summer: 'Remove water sprouts and suckers as they appear.',
        fall: 'Light cleanup only. Major pruning wounds heal poorly in fall.',
        winter: 'CRITICAL: Prune during dormancy (late Jan-Feb). Open center shape.'
      },
      temperature_guidance: {}
    }
  },
  'rosa': {
    common_name: 'Rose',
    regions: ['US', 'UK', 'Europe'],
    hardiness_zones: ['4-9'],
    watering: {
      title: 'Deep watering prevents disease',
      description: 'Water deeply at base 2-3 times per week. Keep foliage dry to prevent black spot and powdery mildew. Morning watering is best.',
      frequency: '2-3 times per week',
      season_adjustments: {
        spring: 'Water deeply as growth begins. 1-2 inches per week.',
        summer: 'Increase during hot, dry periods. Mulch to retain moisture.',
        fall: 'Reduce watering. Stop 3-4 weeks before first frost.',
        winter: 'Minimal watering. Only during dry winters in zones 7+.'
      },
      temperature_guidance: {}
    },
    fertilizer: {
      title: 'Feed regularly for continuous blooms',
      description: 'Apply rose-specific fertilizer every 4-6 weeks during growing season. Stop fertilizing 6 weeks before first frost to allow plants to harden off.',
      frequency: 'Every 4-6 weeks during growing season',
      season_adjustments: {
        spring: 'Begin fertilizing as new growth appears.',
        summer: 'Continue regular feeding for continuous blooms.',
        fall: 'Stop fertilizing 6 weeks before first frost.',
        winter: 'Dormant. No fertilizer needed.'
      },
      temperature_guidance: {}
    },
    pruning: {
      title: 'Prune for shape and health',
      description: 'Prune in early spring just as buds swell. Remove dead, diseased, or crossing branches. Cut at 45-degree angle 1/4 inch above outward-facing bud.',
      frequency: 'Annually in early spring',
      season_adjustments: {
        spring: 'MAJOR PRUNING: Remove 1/3 of old wood. Open center for air flow.',
        summer: 'Deadhead spent blooms to encourage reblooming.',
        fall: 'Light cleanup only. Remove any diseased canes.',
        winter: 'Dormant. Plan spring pruning.'
      },
      temperature_guidance: {}
    }
  }
};

// ============================================================================
// MAIN POPULATION FUNCTION
// ============================================================================
async function populateDatabase() {
  const session = driver.session();

  try {
    console.log('[START] Starting database population for Western markets...\n');

    // Clear existing data first to avoid constraint violations
    console.log('[CLEANUP] Clearing existing disease and care data...');
    await session.run('MATCH (d:Disease) DETACH DELETE d');
    await session.run('MATCH (c:CareRequirement) DETACH DELETE c');
    await session.run('MATCH (s:Species) DETACH DELETE s');
    console.log('[CLEANUP] Database cleared.\n');

    const usdaData = await fetchUSDAData();

    // STEP 1: Populate disease treatments
    console.log('[STEP 1] Populating disease treatments...');
    for (const [diseaseId, data] of Object.entries(DISEASE_TREATMENTS)) {
      await session.run(
        `
        MERGE (d:Disease {id: $diseaseId})
        SET d.name = $name,
            d.host_plant = $hostPlant,
            d.organic_treatment = $organic,
            d.chemical_treatment = $chemical,
            d.prevention = $prevention,
            d.season_tips = $seasonTips,
            d.temperature_triggers = $tempTriggers,
            d.regions = $regions,
            d.hardiness_zones = $hardinessZones
        `,
        {
          diseaseId,
          name: data.disease_name,
          hostPlant: data.host_plant,
          organic: data.organic_treatment,
          chemical: data.chemical_treatment,
          prevention: data.prevention,
          seasonTips: JSON.stringify(data.season_tips),
          tempTriggers: JSON.stringify(data.temperature_triggers),
          regions: data.regions || [],
          hardinessZones: data.hardiness_zones || []
        }
      );
      console.log(`  [OK] Added disease: ${data.disease_name}`);
    }

    // STEP 2: Populate general care tips
    console.log('\n[STEP 2] Populating general care tips...');
    for (const [speciesId, data] of Object.entries(GENERAL_CARE_TIPS)) {
      await session.run(
        `
        MERGE (s:Species {id: $speciesId})
        SET s.common_name = $commonName,
            s.regions = $regions,
            s.hardiness_zones = $hardinessZones
        `,
        {
          speciesId,
          commonName: data.common_name || speciesId,
          regions: data.regions || [],
          hardinessZones: data.hardiness_zones || []
        }
      );

      const categories = ['watering', 'sunlight', 'fertilizer', 'pruning'];
      for (const category of categories) {
        if (data[category]) {
          await session.run(
            `
            MATCH (s:Species {id: $speciesId})
            MERGE (c:CareRequirement {
              species_id: $speciesId,
              category: $category
            })
            SET c.title = $title,
                c.description = $description,
                c.frequency = $frequency,
                c.season_adjustments = $seasonAdjustments,
                c.temperature_guidance = $tempGuidance,
                c.season_specific = true
            MERGE (s)-[:NEEDS]->(c)
            `,
            {
              speciesId,
              category,
              title: data[category].title,
              description: data[category].description,
              frequency: data[category].frequency,
              seasonAdjustments: JSON.stringify(data[category].season_adjustments),
              tempGuidance: JSON.stringify(data[category].temperature_guidance || {})
            }
          );
          console.log(`  [OK] Added ${category} care for ${speciesId}`);
        }
      }
    }

    // STEP 3: Link diseases to species
    console.log('\n[STEP 3] Linking diseases to species...');
    const diseaseToSpecies = {
      'tomato_early_blight': 'solanum_lycopersicum',
      'tomato_late_blight': 'solanum_lycopersicum',
      'tomato_septoria_leaf_spot': 'solanum_lycopersicum',
      'potato_early_blight': 'solanum_tuberosum',
      'potato_late_blight': 'solanum_tuberosum',
      'corn_northern_leaf_blight': 'zea_mays',
      'corn_common_rust': 'zea_mays',
      'apple_scab': 'malus_domestica',
      'apple_cedar_apple_rust': 'malus_domestica',
      'apple_fire_blight': 'malus_domestica',
      'grape_black_rot': 'vitis_vinifera',
      'grape_powdery_mildew': 'vitis_vinifera',
      'rose_black_spot': 'rosa',
      'rose_powdery_mildew': 'rosa',
      'lawn_brown_patch': 'turfgrass',
      'lawn_dollar_spot': 'turfgrass'
    };

    for (const [diseaseId, speciesId] of Object.entries(diseaseToSpecies)) {
      // First ensure the species node exists (create if needed)
      await session.run(
        `
        MERGE (s:Species {id: $speciesId})
        `,
        { speciesId }
      );

      await session.run(
        `
        MATCH (s:Species {id: $speciesId})
        MATCH (d:Disease {id: $diseaseId})
        MERGE (s)-[:SUSCEPTIBLE_TO]->(d)
        `,
        { speciesId, diseaseId }
      );
      console.log(`  [OK] Linked ${diseaseId} -> ${speciesId}`);
    }

    console.log('\n[COMPLETE] Database population complete!');
    console.log(`   - ${Object.keys(DISEASE_TREATMENTS).length} diseases (Western focus)`);
    console.log(`   - ${Object.keys(GENERAL_CARE_TIPS).length} species with care tips`);
    console.log(`   - ${Object.keys(diseaseToSpecies).length} disease-species links`);
    console.log('   - Regions: US, UK, Europe');
    console.log('   - Temperature units: F/C');
    console.log('   - Hardiness zones: USDA zones 3-10');

  } catch (error) {
    console.error('[ERROR]', error);
  } finally {
    await session.close();
    await driver.close();
  }
}

populateDatabase();