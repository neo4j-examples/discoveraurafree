create constraint on (c:Country) assert c.code is unique;
create index on :Country(name);

LOAD CSV WITH HEADERS FROM "https://github.com/neo4j-examples/discoveraurafree/raw/main/data/esc/esc-countries.csv" AS row
MERGE (c:Country {code:row.code}) SET c.name = row.name;

// votes 2022
LOAD CSV WITH HEADERS FROM "https://github.com/neo4j-examples/discoveraurafree/raw/main/data/esc/esc-2022.csv" AS row
WITH * WHERE toInteger(row.total) > 0
MERGE (from:Country {code: row.from})
MERGE (to:Country {code: row.to})
MERGE (from)-[v:VOTES_2022]->(to) 
ON CREATE SET v.total = toInteger(row.total),
v.jury = toInteger(row.jury),
v.public = toInteger(row.public);

// votes 2021
LOAD CSV WITH HEADERS FROM "https://github.com/neo4j-examples/discoveraurafree/raw/main/data/esc/esc-2021.csv" AS row
WITH * WHERE toInteger(row.total) > 0
MERGE (from:Country {code: row.from})
MERGE (to:Country {code: row.to})
MERGE (from)-[v:VOTES_2021]->(to) 
ON CREATE SET v.total = toInteger(row.total),
v.jury = toInteger(row.jury),
v.public = toInteger(row.public);


// votes 1975 to 2019
LOAD CSV WITH HEADERS FROM "https://github.com/neo4j-examples/discoveraurafree/raw/main/data/esc/esc-1975-2019.csv" AS row fieldterminator ';'
// year;round;edition;vote;from;to;points;duplicate
WITH * WHERE coalesce(row.duplicate,'') <> 'x' AND row.round = 'f' AND row.from <> row.to
WITH row.year as year, row.from as fromCountry, row.to as toCountry, 
sum(case row.vote when 'J' then toInteger(row.points) else 0 end) as jury,
sum(case row.vote when 'T' then toInteger(row.points) else 0 end) as public
WHERE public+jury > 0
MERGE (from:Country {name: fromCountry})
MERGE (to:Country {code: toCountry})
WITH *
CALL apoc.create.relationship(from, 'VOTES_'+year, {jury:jury, public:public, total:public+jury}, to) yield rel
RETURN count(*);
