import json
import os
from neo4j import GraphDatabase
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

NEO4J_URI = os.getenv("NEO4J_URI")
NEO4J_USER = os.getenv("NEO4J_USER")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD")
JSON_FILE_PATH = "care_data/plant_care_data.json"

# Hemisphere month mapping
HEMISPHERE_MONTHS = {
    "spring": {"northern": [3, 4, 5], "southern": [9, 10, 11]},
    "summer": {"northern": [6, 7, 8], "southern": [12, 1, 2]},
    "autumn": {"northern": [9, 10, 11], "southern": [3, 4, 5]},
    "winter": {"northern": [12, 1, 2], "southern": [6, 7, 8]}
}

def ingest_care_data():
    # CLOUD-OPTIMIZED DRIVER CONFIGURATION
    driver = GraphDatabase.driver(
        NEO4J_URI, 
        auth=(NEO4J_USER, NEO4J_PASSWORD),
        max_connection_lifetime=3600,  
        connection_timeout=30.0,       
        max_connection_pool_size=50    
    )

    # Verify connection to AuraDB cloud
    try:
        driver.verify_connectivity()
        print("✅ Successfully connected to AuraDB Cloud instance!")
    except Exception as e:
        print(f"❌ Failed to connect to AuraDB: {e}")
        return

    with open(JSON_FILE_PATH, 'r') as f:
        plant_data = json.load(f)

    # Flatten JSON for batch UNWIND
    batch_records = []
    for plant in plant_data:
        species_name = plant["species"]
        for care in plant["care"]:
            category = care["category"]
            general = care["general"]
            
            for season_name, advice in care.get("seasons", {}).items():
                if season_name in HEMISPHERE_MONTHS:
                    batch_records.append({
                        "species_name": species_name,
                        "category": category,
                        "general": general,
                        "season_name": season_name,
                        "adjusted_advice": advice,
                        "northern_months": HEMISPHERE_MONTHS[season_name]["northern"],
                        "southern_months": HEMISPHERE_MONTHS[season_name]["southern"]
                    })

    # Parameterized Cypher query
    cypher_query = """
    UNWIND $batch AS record
    
    MATCH (s:Species {name: record.species_name})
    MERGE (c:CareRequirement {category: record.category, description: record.general})
    MERGE (s)-[:NEEDS]->(c)
    
    MATCH (sn:Season {name: record.season_name})
    MERGE (c)-[d:DURING]->(sn)
    SET d.adjusted_advice = record.adjusted_advice,
        d.northern_months = record.northern_months,
        d.southern_months = record.southern_months
    """

    print(f"☁️ Starting cloud ingestion of {len(batch_records)} care-season records...")
    
    with driver.session() as session:
        # Smaller batches for cloud stability
        batch_size = 250 
        for i in range(0, len(batch_records), batch_size):
            batch = batch_records[i:i + batch_size]
            session.execute_write(lambda tx: tx.run(cypher_query, batch=batch))
            print(f"   -> Uploaded batch {i//batch_size + 1}...")

    driver.close()
    print("🎉 Cloud ingestion complete! Check your AuraDB browser to verify.")

if __name__ == "__main__":
    ingest_care_data()