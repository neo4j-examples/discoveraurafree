#!/usr/bin/python3
# usage: NEO4J_URI="bolt://localhost" NEO4J_PASSWORD=secret ./gedcom2neo4j.py file.ged
# https://pypi.org/project/python-gedcom/
# https://pypi.org/project/neo4j/

import sys
import os
from gedcom.element.individual import IndividualElement
from gedcom.parser import Parser
from neo4j import GraphDatabase

driver = GraphDatabase.driver(os.getenv('NEO4J_URI'), auth=("neo4j", os.getenv('NEO4J_PASSWORD')))

file_path = sys.argv[1]
gedcom_parser = Parser()
gedcom_parser.parse_file(file_path)

root_child_elements = gedcom_parser.get_root_child_elements()

statement_w_cleanup = """
        UNWIND $data as row 
        MERGE (p:Person {id:row.id}) 
        SET p += row {.first, .last,.sex,
            death: toInteger(row.death),birth:toInteger(row.birth)}
        SET p.name = p.first + ' ' + p.last
        MERGE (m:Person {id:coalesce(row.mother,'unknown')})
        MERGE (p)-[:MOTHER]->(m)
        MERGE (f:Person {id:coalesce(row.father,'unknown')})
        MERGE (p)-[:FATHER]->(f)
        WITH count(*) as total
        MATCH (d:Person {id:'unknown'})
        DETACH DELETE d
        RETURN distinct total
        """


statement_conditional = """
        UNWIND $data as row 
        MERGE (p:Person {id:row.id}) 
        SET p += row {.first, .last,.sex,
            death: toInteger(row.death),birth:toInteger(row.birth)}
        SET p.name = p.first + ' ' + p.last
        CALL { WITH row, p
           WITH * WHERE NOT coalesce(row.mother,'') = ''
           MERGE (m:Person {id:row.mother})
           MERGE (p)-[:MOTHER]->(m)
           RETURN count(*) as mothers
        }
        CALL { WITH row, p
           WITH * WHERE NOT coalesce(row.father,'') = ''
           MERGE (f:Person {id:row.father})
           MERGE (p)-[:FATHER]->(f)
           RETURN count(*) as fathers
        }
        RETURN count(*) AS total
        """
data = []
root_child_elements = gedcom_parser.get_root_child_elements()
for e in root_child_elements:
    if isinstance(e, IndividualElement):
        (first,last) = e.get_name()
        row = {"first":first, "last":last}
        row["birth"]=e.get_birth_year()
        row["death"]=e.get_death_year()
        row["gender"]=e.get_gender()
        row["id"]=e.get_pointer()
        parents = gedcom_parser.get_parents(e)
        row["mother"]=next(iter([p.get_pointer() for p in parents if p.get_gender() == 'F']),None)
        row["father"]=next(iter([p.get_pointer() for p in parents if p.get_gender() == 'M']),None)
        data= data + [row]

with driver.session() as session:
    total = session.write_transaction(
        lambda tx: tx.run(statement_w_cleanup, data = data).single()['total'])
    print("Entries added {total}".format(total=total))

