create constraint on (c:Country) assert c.code is unique;
create index on :Country(name);

LOAD CSV WITH HEADERS FROM "url" AS row
MERGE (c:Country {code:row.code}) SET c.name = row.name;

// votes 2022
LOAD CSV WITH HEADERS FROM "url" AS row
MERGE (from:Country {code: row.from})
MERGE (to:Country {code: row.to})
MERGE (from)-[v:VOTES_2022]->(to) 
SET v.total = toInteger(row.total),
v.jury = toInteger(row.jury),
v.public = toInteger(row.public);

// votes 2021
LOAD CSV WITH HEADERS FROM "url" AS row
MERGE (from:Country {code: row.from})
MERGE (to:Country {code: row.to})
MERGE (from)-[v:VOTES_2021]->(to) 
SET v.total = toInteger(row.total),
v.jury = toInteger(row.jury),
v.public = toInteger(row.public);
