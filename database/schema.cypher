// ==========================================
// 1. UNIQUE CONSTRAINTS (Data Integrity)
// ==========================================
CREATE CONSTRAINT species_name_unique FOR (s:Species) REQUIRE s.name IS UNIQUE;
CREATE CONSTRAINT disease_name_unique FOR (d:Disease) REQUIRE d.name IS UNIQUE;
CREATE CONSTRAINT treatment_name_unique FOR (t:Treatment) REQUIRE t.name IS UNIQUE;
CREATE CONSTRAINT pest_name_unique FOR (p:Pest) REQUIRE p.name IS UNIQUE;
CREATE CONSTRAINT soil_type_unique FOR (st:SoilType) REQUIRE st.name IS UNIQUE;
CREATE CONSTRAINT season_name_unique FOR (s:Season) REQUIRE s.name IS UNIQUE;
CREATE CONSTRAINT environment_unique FOR (e:Environment) REQUIRE e.condition IS UNIQUE;
CREATE CONSTRAINT plant_part_unique FOR (pp:PlantPart) REQUIRE pp.name IS UNIQUE;
CREATE CONSTRAINT care_req_unique FOR (cr:CareRequirement) REQUIRE (cr.category, cr.description) IS UNIQUE;

// ==========================================
// 2. INDEXES (Query Performance)
// ==========================================
// Standard B-Tree Indexes for exact matches and filtering
CREATE INDEX species_scientific FOR (s:Species) ON (s.scientific_name);
CREATE INDEX species_family FOR (s:Species) ON (s.family);
CREATE INDEX species_genus FOR (s:Species) ON (s.genus);
CREATE INDEX disease_type FOR (d:Disease) ON (d.type);
CREATE INDEX disease_severity FOR (d:Disease) ON (d.severity);
CREATE INDEX pest_type FOR (p:Pest) ON (p.type);
CREATE INDEX care_category FOR (cr:CareRequirement) ON (cr.category);
CREATE INDEX treatment_type FOR (t:Treatment) ON (t.type);

// Composite Index for common API queries (e.g., finding diseases by type and severity)
CREATE INDEX disease_type_severity FOR (d:Disease) ON (d.type, d.severity);

// Full-text index for searching symptoms and descriptions
CREATE FULLTEXT INDEX speciesAndDiseaseSearch FOR (s:Species|Disease|Pest) ON EACH [s.name, s.common_names, s.description, s.symptoms];