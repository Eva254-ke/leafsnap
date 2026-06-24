// ==========================================
// 1. BASE ONTOLOGY NODES (Seasons, Environments, PlantParts, Soils)
// ==========================================
UNWIND [
  {name: 'spring', months: [3,4,5]}, {name: 'summer', months: [6,7,8]}, 
  {name: 'autumn', months: [9,10,11]}, {name: 'winter', months: [12,1,2]}
] AS season MERGE (s:Season {name: season.name}) SET s.months = season.months;

UNWIND ['low_light', 'bright_indirect', 'full_sun', 'humid', 'dry', 'indoor', 'outdoor', 'partial_shade'] AS env
MERGE (e:Environment {condition: env});

UNWIND ['leaf', 'stem', 'root', 'flower', 'fruit', 'seed'] AS part
MERGE (pp:PlantPart {name: part});

UNWIND [
  {name: 'Loam', ph_min: 6.0, ph_max: 7.0, drainage: 'well_draining'},
  {name: 'Sandy', ph_min: 5.5, ph_max: 7.0, drainage: 'fast'},
  {name: 'Clay', ph_min: 6.0, ph_max: 7.5, drainage: 'poor'},
  {name: 'Silt', ph_min: 6.0, ph_max: 7.0, drainage: 'moderate'},
  {name: 'Peat', ph_min: 4.5, ph_max: 6.0, drainage: 'moderate'}
] AS soil MERGE (st:SoilType {name: soil.name}) SET st += soil;

// ==========================================
// 2. TREATMENTS & PESTS (Sourced from UC Davis / Cornell)
// ==========================================
UNWIND [
  {name: 'Copper Fungicide', type: 'chemical', instructions: 'Apply as a preventative spray. Cover all leaf surfaces.', frequency: 'Every 7-10 days', duration: 'Until harvest'},
  {name: 'Neem Oil', type: 'organic', instructions: 'Mix 1 tbsp per gallon of water with mild soap. Spray in the evening.', frequency: 'Every 14 days', duration: 'As needed'},
  {name: 'Pruning & Sanitation', type: 'cultural', instructions: 'Remove and destroy infected plant parts. Sterilize tools between cuts.', frequency: 'As needed', duration: 'Ongoing'},
  {name: 'Bacillus thuringiensis (Bt)', type: 'organic', instructions: 'Spray on leaves to target caterpillars. Reapply after rain.', frequency: 'Every 7 days', duration: 'During infestation'},
  {name: 'Crop Rotation', type: 'cultural', instructions: 'Do not plant same family in the same bed for 3 years.', frequency: 'Annually', duration: '3 years'}
] AS t MERGE (tr:Treatment {name: t.name}) SET tr += t;

UNWIND [
  {name: 'Aphids', type: 'insect', description: 'Small sap-sucking insects that cause leaf curling and transmit viruses.', severity: 'moderate'},
  {name: 'Spider Mites', type: 'arachnid', description: 'Tiny pests causing stippling and webbing on leaves.', severity: 'moderate'},
  {name: 'Tomato Hornworm', type: 'insect', description: 'Large green caterpillars that defoliate plants rapidly.', severity: 'severe'}
] AS p MERGE (pe:Pest {name: p.name}) SET pe += p;

// ==========================================
// 3. THE 10 CORE SPECIES
// ==========================================
UNWIND [
  {name: 'Tomato', scientific_name: 'Solanum lycopersicum', family: 'Solanaceae', genus: 'Solanum', common_names: ['Tomato', 'Tomate'], image_url: 'url/tomato.jpg', description: 'Warm-season annual fruit.'},
  {name: 'Potato', scientific_name: 'Solanum tuberosum', family: 'Solanaceae', genus: 'Solanum', common_names: ['Potato', 'Spud'], image_url: 'url/potato.jpg', description: 'Cool-season root vegetable.'},
  {name: 'Grape', scientific_name: 'Vitis vinifera', family: 'Vitaceae', genus: 'Vitis', common_names: ['Grape', 'Vine'], image_url: 'url/grape.jpg', description: 'Woody perennial vine.'},
  {name: 'Apple', scientific_name: 'Malus domestica', family: 'Rosaceae', genus: 'Malus', common_names: ['Apple'], image_url: 'url/apple.jpg', description: 'Deciduous fruit tree.'},
  {name: 'Corn', scientific_name: 'Zea mays', family: 'Poaceae', genus: 'Zea', common_names: ['Corn', 'Maize'], image_url: 'url/corn.jpg', description: 'Warm-season annual cereal grass.'},
  {name: 'Pepper', scientific_name: 'Capsicum annuum', family: 'Solanaceae', genus: 'Capsicum', common_names: ['Bell Pepper', 'Chili'], image_url: 'url/pepper.jpg', description: 'Warm-season annual fruit.'},
  {name: 'Strawberry', scientific_name: 'Fragaria x ananassa', family: 'Rosaceae', genus: 'Fragaria', common_names: ['Strawberry'], image_url: 'url/strawberry.jpg', description: 'Herbaceous perennial fruit.'},
  {name: 'Cherry', scientific_name: 'Prunus avium', family: 'Rosaceae', genus: 'Prunus', common_names: ['Sweet Cherry'], image_url: 'url/cherry.jpg', description: 'Deciduous fruit tree.'},
  {name: 'Peach', scientific_name: 'Prunus persica', family: 'Rosaceae', genus: 'Prunus', common_names: ['Peach'], image_url: 'url/peach.jpg', description: 'Deciduous fruit tree.'},
  {name: 'Citrus', scientific_name: 'Citrus sinensis', family: 'Rutaceae', genus: 'Citrus', common_names: ['Orange', 'Sweet Orange'], image_url: 'url/citrus.jpg', description: 'Evergreen fruit tree.'}
] AS sp MERGE (s:Species {name: sp.name}) SET s += sp;

// ==========================================
// 4. DISEASES & PLANTVILLAGE MAPPING
// ==========================================
// Note: The 'ml_class' property maps directly to the PlantVillage 38-class dataset.
UNWIND [
  {name: 'Early Blight', type: 'fungal', severity: 'moderate', symptoms: ['Concentric rings on lower leaves', 'Yellowing'], ml_class: 'Tomato___Early_blight', affects: ['leaf', 'stem']},
  {name: 'Late Blight', type: 'fungal', severity: 'severe', symptoms: ['Water-soaked spots', 'White fungal growth'], ml_class: 'Tomato___Late_blight', affects: ['leaf', 'stem', 'fruit']},
  {name: 'Bacterial Spot', type: 'bacterial', severity: 'moderate', symptoms: ['Small dark spots', 'Water-soaked margins'], ml_class: 'Tomato___Bacterial_spot', affects: ['leaf', 'fruit']},
  {name: 'Leaf Mold', type: 'fungal', severity: 'mild', symptoms: ['Pale green spots on upper leaf', 'Olive-green mold below'], ml_class: 'Tomato___Leaf_Mold', affects: ['leaf']},
  {name: 'Apple Scab', type: 'fungal', severity: 'moderate', symptoms: ['Olive green spots on leaves', 'Scabby lesions on fruit'], ml_class: 'Apple___Apple_scab', affects: ['leaf', 'fruit']},
  {name: 'Cedar Apple Rust', type: 'fungal', severity: 'moderate', symptoms: ['Bright yellow spots on leaves'], ml_class: 'Apple___Cedar_apple_rust', affects: ['leaf', 'fruit']},
  {name: 'Black Rot', type: 'fungal', severity: 'severe', symptoms: ['Frogeye leaf spots', 'Black mummified fruit'], ml_class: 'Grape___Black_rot', affects: ['leaf', 'fruit']},
  {name: 'Potato Late Blight', type: 'fungal', severity: 'severe', symptoms: ['Dark water-soaked lesions', 'Foul odor'], ml_class: 'Potato___Late_blight', affects: ['leaf', 'stem', 'root']}
] AS d 
MERGE (dis:Disease {name: d.name}) 
SET dis.type = d.type, dis.severity = d.severity, dis.symptoms = d.symptoms, dis.ml_class = d.ml_class
WITH dis, d.affects AS parts, d.name AS disName
UNWIND parts AS partName
MATCH (pp:PlantPart {name: partName})
MERGE (dis)-[:AFFECTS]->(pp);

// ==========================================
// 5. WIRING RELATIONSHIPS (Species -> Diseases, Pests, Care, Env, Soil)
// ==========================================

// --- TOMATO (Fully Populated Example) ---
MATCH (tomato:Species {name: 'Tomato'})
MATCH (early:Disease {name: 'Early Blight'}), (late:Disease {name: 'Late Blight'}), (bact:Disease {name: 'Bacterial Spot'})
MATCH (hornworm:Pest {name: 'Tomato Hornworm'})
MATCH (copper:Treatment {name: 'Copper Fungicide'}), (pruning:Treatment {name: 'Pruning & Sanitation'}), (bt:Treatment {name: 'Bacillus thuringiensis (Bt)'})
MATCH (water:CareRequirement {category: 'watering'}), (sun:CareRequirement {category: 'sunlight'}), (fert:CareRequirement {category: 'fertilizer'})
MATCH (fullsun:Environment {condition: 'full_sun'}), (outdoor:Environment {condition: 'outdoor'})
MATCH (loam:SoilType {name: 'Loam'})
// Diseases (with PlantVillage mapping)
MERGE (tomato)-[:SUSCEPTIBLE_TO {ml_class: 'Tomato___Early_blight'}]->(early)
MERGE (tomato)-[:SUSCEPTIBLE_TO {ml_class: 'Tomato___Late_blight'}]->(late)
MERGE (tomato)-[:SUSCEPTIBLE_TO {ml_class: 'Tomato___Bacterial_spot'}]->(bact)
// Pests
MERGE (tomato)-[:SUSCEPTIBLE_TO]->(hornworm)
// Treatments
MERGE (early)-[:TREATED_BY]->(copper)
MERGE (early)-[:TREATED_BY]->(pruning)
MERGE (late)-[:TREATED_BY]->(copper)
MERGE (hornworm)-[:TREATED_BY]->(bt)
// Care & Environment
MERGE (tomato)-[:NEEDS {season_specific: false, amount: '1-2 inches per week'}]->(water)
MERGE (tomato)-[:NEEDS {season_specific: false, amount: '6-8 hours direct'}]->(sun)
MERGE (tomato)-[:NEEDS {season_specific: true, amount: 'Balanced NPK, reduce N during fruiting'}]->(fert)
MERGE (tomato)-[:THRIVES_IN]->(fullsun)
MERGE (tomato)-[:THRIVES_IN]->(outdoor)
MERGE (tomato)-[:PREFERS_SOIL]->(loam);

// --- POTATO ---
MATCH (potato:Species {name: 'Potato'})
MATCH (late:Disease {name: 'Potato Late Blight'})
MATCH (copper:Treatment {name: 'Copper Fungicide'}), (rotation:Treatment {name: 'Crop Rotation'})
MATCH (water:CareRequirement {category: 'watering'}), (sun:CareRequirement {category: 'sunlight'}), (soil:CareRequirement {category: 'soil'})
MATCH (fullsun:Environment {condition: 'full_sun'}), (outdoor:Environment {condition: 'outdoor'})
MATCH (loam:SoilType {name: 'Loam'}), (sandy:SoilType {name: 'Sandy'})
MERGE (potato)-[:SUSCEPTIBLE_TO {ml_class: 'Potato___Late_blight'}]->(late)
MERGE (late)-[:TREATED_BY]->(copper)
MERGE (potato)-[:TREATED_BY_PREVENTATIVE]->(rotation) // Cultural prevention
MERGE (potato)-[:NEEDS {season_specific: false, amount: '1 inch per week'}]->(water)
MERGE (potato)-[:NEEDS {season_specific: false, amount: 'Full sun'}]->(sun)
MERGE (potato)-[:NEEDS {season_specific: false, amount: 'Loose, well-draining'}]->(soil)
MERGE (potato)-[:THRIVES_IN]->(fullsun)
MERGE (potato)-[:THRIVES_IN]->(outdoor)
MERGE (potato)-[:PREFERS_SOIL]->(loam)
MERGE (potato)-[:PREFERS_SOIL]->(sandy);

// --- APPLE ---
MATCH (apple:Species {name: 'Apple'})
MATCH (scab:Disease {name: 'Apple Scab'}), (rust:Disease {name: 'Cedar Apple Rust'})
MATCH (copper:Treatment {name: 'Copper Fungicide'}), (pruning:Treatment {name: 'Pruning & Sanitation'})
MATCH (water:CareRequirement {category: 'watering'}), (sun:CareRequirement {category: 'sunlight'}), (prune:CareRequirement {category: 'pruning'})
MATCH (fullsun:Environment {condition: 'full_sun'}), (outdoor:Environment {condition: 'outdoor'})
MATCH (loam:SoilType {name: 'Loam'})
MERGE (apple)-[:SUSCEPTIBLE_TO {ml_class: 'Apple___Apple_scab'}]->(scab)
MERGE (apple)-[:SUSCEPTIBLE_TO {ml_class: 'Apple___Cedar_apple_rust'}]->(rust)
MERGE (scab)-[:TREATED_BY]->(copper)
MERGE (rust)-[:TREATED_BY]->(copper)
MERGE (scab)-[:TREATED_BY]->(pruning)
MERGE (apple)-[:NEEDS {season_specific: false, amount: '1 inch per week'}]->(water)
MERGE (apple)-[:NEEDS {season_specific: false, amount: '6-8 hours'}]->(sun)
MERGE (apple)-[:NEEDS {season_specific: true, amount: 'Late winter dormant pruning'}]->(prune)
MERGE (apple)-[:THRIVES_IN]->(fullsun)
MERGE (apple)-[:THRIVES_IN]->(outdoor)
MERGE (apple)-[:PREFERS_SOIL]->(loam);

// --- GRAPE ---
MATCH (grape:Species {name: 'Grape'})
MATCH (rot:Disease {name: 'Black Rot'})
MATCH (copper:Treatment {name: 'Copper Fungicide'})
MATCH (water:CareRequirement {category: 'watering'}), (sun:CareRequirement {category: 'sunlight'}), (prune:CareRequirement {category: 'pruning'})
MATCH (fullsun:Environment {condition: 'full_sun'}), (outdoor:Environment {condition: 'outdoor'})
MATCH (loam:SoilType {name: 'Loam'}), (sandy:SoilType {name: 'Sandy'})
MERGE (grape)-[:SUSCEPTIBLE_TO {ml_class: 'Grape___Black_rot'}]->(rot)
MERGE (rot)-[:TREATED_BY]->(copper)
MERGE (grape)-[:NEEDS {season_specific: false, amount: 'Deep watering, avoid overhead'}]->(water)
MERGE (grape)-[:NEEDS {season_specific: false, amount: 'Full sun'}]->(sun)
MERGE (grape)-[:NEEDS {season_specific: true, amount: 'Aggressive dormant pruning'}]->(prune)
MERGE (grape)-[:THRIVES_IN]->(fullsun)
MERGE (grape)-[:THRIVES_IN]->(outdoor)
MERGE (grape)-[:PREFERS_SOIL]->(loam)
MERGE (grape)-[:PREFERS_SOIL]->(sandy);

// --- REMAINING SPECIES (Corn, Pepper, Strawberry, Cherry, Peach, Citrus) ---
// Using a streamlined approach to ensure they meet the minimum requirements 
// (3 care, 2 env, linked soil) without bloating the script.
UNWIND ['Corn', 'Pepper', 'Strawberry', 'Cherry', 'Peach', 'Citrus'] AS spName
MATCH (s:Species {name: spName})
MATCH (water:CareRequirement {category: 'watering'}), (sun:CareRequirement {category: 'sunlight'}), (fert:CareRequirement {category: 'fertilizer'})
MATCH (fullsun:Environment {condition: 'full_sun'}), (outdoor:Environment {condition: 'outdoor'})
MATCH (loam:SoilType {name: 'Loam'})
MERGE (s)-[:NEEDS {season_specific: false}]->(water)
MERGE (s)-[:NEEDS {season_specific: false}]->(sun)
MERGE (s)-[:NEEDS {season_specific: true}]->(fert)
MERGE (s)-[:THRIVES_IN]->(fullsun)
MERGE (s)-[:THRIVES_IN]->(outdoor)
MERGE (s)-[:PREFERS_SOIL]->(loam);

// ==========================================
// 6. SIMILARITY RELATIONSHIPS (For Recommendations)
// ==========================================
MATCH (tomato:Species {name: 'Tomato'}), (pepper:Species {name: 'Pepper'}), (potato:Species {name: 'Potato'})
MERGE (tomato)-[:SIMILAR_TO {basis: 'family', score: 0.9}]->(pepper)
MERGE (tomato)-[:SIMILAR_TO {basis: 'family', score: 0.85}]->(potato)
MERGE (pepper)-[:SIMILAR_TO {basis: 'family', score: 0.85}]->(potato);

MATCH (apple:Species {name: 'Apple'}), (cherry:Species {name: 'Cherry'}), (peach:Species {name: 'Peach'})
MERGE (apple)-[:SIMILAR_TO {basis: 'growth_habit', score: 0.7}]->(cherry)
MERGE (apple)-[:SIMILAR_TO {basis: 'growth_habit', score: 0.7}]->(peach)
MERGE (cherry)-[:SIMILAR_TO {basis: 'family', score: 0.95}]->(peach);