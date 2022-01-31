:history

MATCH p=()-[r:SIBLING]->() RETURN p LIMIT 25;

MATCH (p:Person)-[:MOTHER|FATHER]-(parent)
MATCH (sib:Person)-[:MOTHER|FATHER]-(parent)
WHERE p <> sib
MERGE (p)-[:SIBLING]-(sib);

MATCH (n:Person) RETURN n LIMIT 25;

MATCH (n:CoreFamily) RETURN n LIMIT 25;

MATCH (fam:CoreFamily)<-[rel]-(person)
WHERE exists { (person)<-[:MOTHER|FATHER]-(child)-->(fam) }
SET rel.role = 'parent';

MATCH (fam:CoreFamily)<-[rel]-(person)
WHERE exists { (person)-[:MOTHER|FATHER]->(parent)-->(fam) }
SET rel.role = 'child';

MATCH (n:CoreFamily) RETURN n LIMIT 25;

MATCH (p:Person)
OPTIONAL MATCH (p)-[:FATHER]->(f)
OPTIONAL MATCH (p)-[:MOTHER]->(m)
WITH p,f,m,coalesce(f,m,p) as member
MERGE (member)-[:CORE_FAMILY]->(fam:CoreFamily {name:member.last})
WITH fam, [x IN [p,m,f] WHERE NOT x IS null]  as people
UNWIND people as person
MERGE (person)-[:CORE_FAMILY]->(fam);

MATCH (n:Family) WHERE n.name contains 'Kennedy' RETURN n LIMIT 25;

MATCH (n:Family) RETURN n LIMIT 25;

MATCH (p:Person)
OPTIONAL MATCH (p)-[:FATHER]->(f)
OPTIONAL MATCH (p)-[:MOTHER]->(m)
MERGE (fam:Family {name:p.last})
WITH fam, [x IN [p,m,f] WHERE NOT x IS null]  as people
UNWIND people as person
MERGE (person)-[:FAMILY]->(fam);

MATCH (p:Person)
OPTIONAL MATCH (p)-[:FATHER]->(f)
OPTIONAL MATCH (p)-[:MOTHER]->(m)
MERGE (fam:Family {name:p.last})
MERGE (p)-[:FAMILY]->(fam)
MERGE (f)-[:FAMILY]->(fam)
MERGE (m)-[:FAMILY]->(fam);

MATCH (n:Person) RETURN n LIMIT 25;

MATCH p=()-->() RETURN p LIMIT 25;

match (p:Person) set p.name = p.first+" "+p.last;

MATCH p=()-->() RETURN p LIMIT 25;

:guide intro

:play https://guides.neo4j.com/graph-examples/northwind-recommendation-engine/graph_guide

MATCH p=()-[r:OCCURRED]->() RETURN p LIMIT 25;

MATCH (t1:Tag)<-[:TAGGED]-()-[:TAGGED]->(t2:Tag)
WHERE id(t1) < id(t2) and t1.name <> 'neo4j' and t2.name <> 'neo4j'
WITH t1, t2,count(*) as freq  where freq > 3
MERGE (t1)-[r:OCCURRED]-(t2) SET r.freq=freq
RETURN count(*);

MATCH (t1:Tag)<-[:TAGGED]-()-[:TAGGED]->(t2:Tag)
WHERE id(t1) < id(t2) and t1.name <> 'neo4j' and t2.name <> 'neo4j'
RETURN t1.name, t2.name,count(*) as freq
ORDER BY freq desc LIMIT 10;

MATCH (q:Question)-[:TAGGED]->(t:Tag)
WHERE NOT t.name IN ['neo4j','cypher']
  AND NOT (q)<-[:ANSWERED]-()
RETURN t.name as tag, count(q) AS questions
ORDER BY questions DESC LIMIT 10;

MATCH (u:User)-[:PROVIDED]->()-[:ANSWERED]->
      (q:Question)-[:TAGGED]->(t:Tag)
WHERE u.display_name = "InverseFalcon"
RETURN apoc.date.format(q.creation_date,'s','yyyy-MM') as month,
       count(distinct q) as count, collect(distinct t.name) as tags
ORDER BY month asc;

MATCH path = allShortestPaths(
  (u1:User {display_name:"alexanoid"})-[*..20]-(u2:User {display_name:"InverseFalcon"})
)
RETURN path LIMIT 10;

MATCH path = allShortestPaths(
  (u1:User {display_name:"alexanoid"})-[*..20]-(u2:User {display_name:"InverseFalcon"})
)
RETURN path LIMIT 1;

MATCH (u:User)-[:PROVIDED]->(a:Answer)-[:ANSWERED]->
      (q:Question)-[:TAGGED]->(:Tag {name:"cypher"})
RETURN u.display_name as user,COUNT(a) AS answers, max(a.score) as max_score
ORDER BY max_score DESC LIMIT 10;

MATCH (u:User)-[:ASKED]->(q:Question)
RETURN u.display_name, count(*) AS questions
ORDER by questions DESC
LIMIT 10;

MATCH (q:Question)-[:TAGGED]->(t:Tag)
RETURN t.name,  count(q) AS questions
ORDER BY questions DESC
LIMIT 5;

:play sandbox/stackoverflow/index.html

MATCH (n)
RETURN labels(n) as label, count(*);

:play sandbox/stackoverflow/index.html

call db.schema.visualization;

:auto WITH ["neo4j"] as tags
UNWIND tags as tagName
UNWIND range(1,10) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=50&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

call { with q
// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
)
} in transactions of 25 rows

WITH "https://api.stackexchange.com/2.3/questions?page=1&pagesize=5&order=desc&sort=creation&tagged=neo4j&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
RETURN value;

:use neo4j

:guide intro

call dbms.security.listRoles();

call dbms.security.listUsers();

call apoc.help();

call dbms.procedures();

:use system

CALL db.schema.visualization;

MATCH p=()-[r:OCCURRED]->() delete r;

MATCH p=()-[r:OCCURRED]->() RETURN p LIMIT 25;

CALL db.schema.visualization;

:play sandbox/stackoverflow/index.html

MATCH p1=(u1:User)-[:COMMENTED]->(c1:Comment)-[:COMMENTED_ON]-(q:Question)
MATCH p2=(u2:User)-[:COMMENTED]->(c2:Comment)-[:COMMENTED_ON]-(q)
WHERE id(u1) < id(u2)
WITH u1, u2, count(distinct q) as freq
WHERE freq > 2
RETURN u1, u2, apoc.create.vRelationship(u1,'OCCURRED',{freq:freq},u2) as rel;

MATCH (t1:Tag)<-[:TAGGED]-()-[:TAGGED]->(t2:Tag)
WHERE id(t1) < id(t2) and t1.name <> 'neo4j' and t2.name <> 'neo4j'
WITH t1, t2,count(*) as freq  where freq > 3
MERGE (t1)-[r:OCCURRED]-(t2) SET r.freq=freq
RETURN count(*);

MATCH (t1:Tag)<-[:TAGGED]-()-[:TAGGED]->(t2:Tag)
WHERE id(t1) < id(t2) and t1.name <> 'neo4j' and t2.name <> 'neo4j'
WITH t1, t2,count(*) as freq  where freq > 3
RETURN t1,t2, apoc.create.vRelationship(t1,'OCCURRED',{freq:freq},t2) as rel;

MATCH (t1:Tag)<-[:TAGGED]-()-[:TAGGED]->(t2:Tag)
WHERE id(t1) < id(t2) and t1.name <> 'neo4j' and t2.name <> 'neo4j'
RETURN t1.name, t2.name,count(*) as freq
ORDER BY freq desc LIMIT 10;

MATCH (q:Question)-[:TAGGED]->(t:Tag)
WHERE NOT t.name IN ['neo4j','cypher']
  AND NOT (q)<-[:ANSWERED]-()
RETURN t.name as tag, count(q) AS questions
ORDER BY questions DESC LIMIT 10;

MATCH (u:User)-[:PROVIDED]->()-[:ANSWERED]->
      (q:Question)-[:TAGGED]->(t:Tag)
WHERE u.display_name = "InverseFalcon"
RETURN apoc.date.format(q.creation_date,'s','yyyy-MM') as month,
       count(distinct q) as count, collect(distinct t.name) as tags
ORDER BY month asc;

:style reset

MATCH path = allShortestPaths(
  (u1:User {display_name:"alexanoid"})-[*]-(u2:User {display_name:"InverseFalcon"})
)
RETURN path LIMIT 1;

MATCH (u:User)-[:PROVIDED]->(a:Answer)-[:ANSWERED]->
      (q:Question)-[:TAGGED]->(:Tag {name:"cypher"})
RETURN u.display_name as user,COUNT(a) AS answers, max(a.score) as max_score
ORDER BY max_score DESC LIMIT 10;

MATCH (u:User)-[:PROVIDED]->(a:Answer)-[:ANSWERED]->(q:Question)
RETURN u.display_name as user,COUNT(a) AS answers, avg(a.score) as avg_score
ORDER BY answers DESC LIMIT 10;

MATCH (u:User)-[:ASKED]->(q:Question)
RETURN u.display_name, count(*) AS questions
ORDER by questions DESC
LIMIT 10;

MATCH (q:Question)-[:TAGGED]->(t:Tag)
RETURN t.name,  count(q) AS questions
ORDER BY questions DESC
LIMIT 5;

:auto WITH ["neo4j"] as tags
UNWIND tags as tagName
UNWIND range(1,10) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=50&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

call { with q
// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
)
} in transactions of 25 rows

:auto WITH ["neo4j"] as tags
UNWIND tags as tagName
UNWIND range(1,2) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=50&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

call { with q
// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
)
} in transactions of 25 rows

:auto WITH ["neo4j"] as tags
UNWIND tags as tagName
UNWIND range(1,2) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=100&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

call { with q
// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
)
} in transactions of 25 rows

:auto WITH ["neo4j"] as tags
UNWIND tags as tagName
UNWIND range(1,2) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=50&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

call { with q
// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
)
} in transactions of 25 rows

:auto
// look for several pages of questions
WITH ["neo4j"] as tags
UNWIND tags as tagName
UNWIND range(1,2) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=50&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

call { with q
// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
)
} in transactions of 25 rows

// look for several pages of questions
WITH ["neo4j"] as tags
UNWIND tags as tagName
UNWIND range(1,2) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=50&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

call { with q
// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
)
} in transactions of 25 rows;

// look for several pages of questions
WITH ["neo4j"] as tags
UNWIND tags as tagName
UNWIND range(1,2) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=50&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
);

// look for several pages of questions
WITH ["neo4j"] as tags
UNWIND tags as tagName
UNWIND range(1,1) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=50&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
);

MATCH (q:Question)-[:TAGGED]->(t:Tag)
RETURN t.name,  count(q) AS questions
ORDER BY questions DESC
LIMIT 5;

// look for several pages of questions
WITH ["neo4j"] as tags
UNWIND tags as tagName
UNWIND range(1,1) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=100&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
);

// look for several pages of questions
WITH ["neo4j"] as tags
UNWIND tags as tagName
UNWIND range(1,2) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=100&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
);

// look for several pages of questions
WITH ["neo4j","cypher"] as tags
UNWIND tags as tagName
UNWIND range(1,2) as page

WITH "https://api.stackexchange.com/2.3/questions?page="+page+"&pagesize=100&order=desc&sort=creation&tagged="+tagName+"&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" as url

CALL apoc.load.json(url) YIELD value
CALL apoc.util.sleep(250)  // careful with throttling

UNWIND value.items AS q

// create the questions
MERGE (question:Question {uuid:q.question_id})
  ON CREATE SET question.title = q.title,
  	question.link = q.share_link,
  	question.creation_date = q.creation_date,
  	question.accepted_answer_id=q.accepted_answer_id,
  	question.view_count=q.view_count,
   	question.answer_count=q.answer_count,
   	question.body_markdown=q.body_markdown

// who asked the question
MERGE (owner:User {uuid:coalesce(q.owner.user_id,'deleted')})
  ON CREATE SET owner.display_name = q.owner.display_name
MERGE (owner)-[:ASKED]->(question)

// what tags do the questions have
FOREACH (tagName IN q.tags |
  MERGE (tag:Tag {name:tagName})
    ON CREATE SET tag.link = "https://stackoverflow.com/questions/tagged/" + tag.name
  MERGE (question)-[:TAGGED]->(tag))

// who answered the questions?
FOREACH (a IN q.answers |
   MERGE (question)<-[:ANSWERED]-(answer:Answer {uuid:a.answer_id})
    ON CREATE SET answer.is_accepted = a.is_accepted,
    answer.link=a.share_link,
    answer.title=a.title,
    answer.body_markdown=a.body_markdown,
    answer.score=a.score,
   	answer.favorite_score=a.favorite_score,
   	answer.view_count=a.view_count
   MERGE (answerer:User {uuid:coalesce(a.owner.user_id,'deleted')})
    ON CREATE SET answerer.display_name = a.owner.display_name
   MERGE (answer)<-[:PROVIDED]-(answerer)
)

// who commented ont he question
FOREACH (c in q.comments |
  MERGE (question)<-[:COMMENTED_ON]-(comment:Comment {uuid:c.comment_id})
    ON CREATE SET comment.link=c.link, comment.score=c.score
  MERGE (commenter:User {uuid:coalesce(c.owner.user_id,'deleted')})
    ON CREATE SET commenter.display_name = c.owner.display_name
  MERGE (comment)<-[:COMMENTED]-(commenter)
);

:guide sandbox/stackoverflow/index.html

:guide intro

:guide aura/cybersecurity

MATCH (n:NFT) RETURN n LIMIT 25;

match (n) return n limit 200;

MATCH p=()-[r:PARENT*5]->() RETURN p LIMIT 25;

MATCH p=()-[r:PARENT]->() RETURN p LIMIT 25;

MATCH (n:Person) RETURN n LIMIT 25;

profile 
match (u:User), (c:Computer), (g:Group)
WHERE u.name contains 'a'
return count(*);

SHOW TRANSACTIONS YIELD *;

profile 
match (u:User), (c:Computer), (g:Group)
WHERE u.name contains 'a'
return count(*);

SHOW TRANSACTIONS YIELD *;

SHOW TRANSACTIONS;

call dbms.listTransactions;

profile 
match (u:User), (c:Computer), (g:Group)
WHERE u.name contains 'a'
return count(*);

call dbms.listTransactions;

:show query

profile 
match (u:User), (c:Computer), (g:Group)
WHERE u.name contains 'a'
return count(*);

explain 
match (u:User), (c:Computer), (g:Group)
WHERE u.name contains 'a'
return count(*);

explain 
match (:User), (:Computer), (:Group)
return count(*);

:guide intro

MATCH (t:Trader)-[:SOLD]->(st:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Price_USD > 100
MATCH (t)-[:BOUGHT]->(bt:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Datetime_updated_seconds > bt.Datetime_updated_seconds
RETURN coalesce(t.username, t.address) as trader, 
       nft.Image_url_1 as nft, 
       nft.ID_token AS tokenID,
       st.Datetime_updated_seconds AS soldTime,
       st.Price_USD AS soldAmount,
       bt.Datetime_updated_seconds as boughtTime,
       bt.Price_USD AS boughtAmount,
       st.Price_USD - bt.Price_USD AS difference
ORDER BY difference DESC LIMIT 5;

MATCH (t:Trader)-[:SOLD]->(st:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Price_USD > 1000
MATCH (t)-[:BOUGHT]->(bt:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Datetime_updated_seconds > bt.Datetime_updated_seconds
RETURN coalesce(t.username, t.address) as trader, 
       nft.Image_url_1 as nft, 
       nft.ID_token AS tokenID,
       st.Datetime_updated_seconds AS soldTime,
       st.Price_USD AS soldAmount,
       bt.Datetime_updated_seconds as boughtTime,
       bt.Price_USD AS boughtAmount,
       st.Price_USD - bt.Price_USD AS difference
ORDER BY difference DESC LIMIT 5;

MATCH (t:Trader)-[:SOLD]->(st:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Price_USD > 100000
MATCH (t)-[:BOUGHT]->(bt:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Datetime_updated_seconds > bt.Datetime_updated_seconds
RETURN coalesce(t.username, t.address) as trader, 
       nft.Image_url_1 as nft, 
       nft.ID_token AS tokenID,
       st.Datetime_updated_seconds AS soldTime,
       st.Price_USD AS soldAmount,
       bt.Datetime_updated_seconds as boughtTime,
       bt.Price_USD AS boughtAmount,
       st.Price_USD - bt.Price_USD AS difference
ORDER BY difference DESC LIMIT 5;

MATCH (t:Trader)
CALL { WITH t 
  MATCH (t)-[:BOUGHT]->(bt)
  RETURN sum(bt.Price_USD) AS boughtVolume
}
CALL { WITH t 
  MATCH (t)-[:SOLD]->(st)
  RETURN sum(st.Price_USD) AS soldVolume
}
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, 
       soldVolume
ORDER BY boughtVolume + soldVolume
DESC LIMIT 5;

MATCH (t:Trader)
CALL { WITH t 
  MATCH (t)-[:BOUGHT]->(bt)
  RETURN sum(bt.Price_USD) AS boughtVolume
}
OPTIONAL MATCH (t)-[:SOLD]->(st)
WITH t, boughtVolume, sum(st.Price_USD) AS soldVolume
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, 
       soldVolume
ORDER BY boughtVolume + soldVolume
DESC LIMIT 5;

MATCH (t:Trader)
OPTIONAL MATCH (t)-[:BOUGHT]->(bt)
WITH t, sum(bt.Price_USD) AS boughtVolume
OPTIONAL MATCH (t)-[:SOLD]->(st)
WITH t, boughtVolume, sum(st.Price_USD) AS soldVolume
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, 
       soldVolume
ORDER BY boughtVolume + soldVolume
DESC LIMIT 5;

MATCH (t:Trader)
MATCH (t)-[:BOUGHT]->(bt)
WITH t, sum(bt.Price_USD) AS boughtVolume
OPTIONAL MATCH (t)-[:SOLD]->(st)
WITH t, boughtVolume, sum(st.Price_USD) AS soldVolume
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, 
       soldVolume
ORDER BY boughtVolume + soldVolume
DESC LIMIT 5;

MATCH (t:Trader)
MATCH (t)-[:BOUGHT]->(bt)
WITH t, sum(bt.Price_USD) AS boughtVolume
MATCH (t)-[:SOLD]->(st)
WITH t, boughtVolume, sum(st.Price_USD) AS soldVolume
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, 
       soldVolume
ORDER BY boughtVolume + soldVolume
DESC LIMIT 5;

MATCH (t:Trader)
OPTIONAL MATCH (t)-[:BOUGHT]->(bt)
WITH t, sum(bt.Price_USD) AS boughtVolume
OPTIONAL MATCH (t)-[:SOLD]->(st)
WITH t, boughtVolume, sum(st.Price_USD) AS soldVolume
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, 
       soldVolume
ORDER BY boughtVolume + soldVolume
DESC LIMIT 5;

MATCH (t:Trader)
RETURN t.username+"-"+t.address AS username,
       size((t)-[:BOUGHT]->()) AS bought,
       size((t)-[:SOLD]->()) AS sold
ORDER BY bought + sold desc LIMIT 50;

MATCH (t:Trader)
RETURN t.username+"-"+t.address AS username,
       size((t)-[:BOUGHT]->()) AS bought,
       size((t)-[:SOLD]->()) AS sold
ORDER BY bought + sold desc LIMIT 5;

MATCH (t:Trader)
RETURN coalesce(t.username, t.address) AS username,
       size((t)-[:BOUGHT]->()) AS bought,
       size((t)-[:SOLD]->()) AS sold
ORDER BY bought + sold desc LIMIT 5;

match (t:Trader) where t.address = '0x0000000000000000000000000000000000000000' return t;

MATCH (collection)<-[:IN_COLLECTION]-(n:NFT)<-[:FOR_NFT]-(t:Transaction)
WHERE exists (t.Price_USD)
RETURN collection.Collection AS collection, 
       avg(t.Price_USD) AS averagePrice, 
       count(distinct n) AS numberOfNfts
ORDER BY averagePrice DESC
LIMIT 5;

MATCH (n:NFT)<-[:FOR_NFT]-(t:Transaction),
      (t)<-[:BOUGHT]-(buyer),
      (t)<-[:SOLD]-(seller)
WHERE n.Name = 'See You Later'
RETURN *;

MATCH (n:NFT)<-[:FOR_NFT]-(t:Transaction),
      (t)<-[:BOUGHT]-(buyer),
      (t)<-[:SOLD]-(seller)
WHERE n.Name = 'See You Later'
RETURN buyer.address AS buyer, 
       seller.address AS seller, 
       t.Datetime_updated_seconds AS date, 
       t.Price_USD AS price;

match (n:NFT)
RETURN n, size( (n)<-[:FOR_NFT]-()) as deg
ORDER BY deg DESC LIMIT 20;

:history

MATCH (n:NFT)<-[:FOR_NFT]-(t:Transaction),
      (t)<-[:BOUGHT]-(buyer),
      (t)<-[:SOLD]-(seller)
WHERE n.Name = 'CryptoPunk #9368'
RETURN buyer.address AS buyer, 
       seller.address AS seller, 
       t.Datetime_updated_seconds AS date, 
       t.Price_USD AS price;

MATCH (n:NFT)<-[:FOR_NFT]-(t:Transaction),
      (t)<-[:BOUGHT]-(buyer),
      (t)<-[:SOLD]-(seller)
WHERE t.Name = 'CryptoPunk #9368'
RETURN buyer.address AS buyer, 
       seller.address AS seller, 
       t.Datetime_updated_seconds AS date, 
       t.Price_USD AS price;

MATCH (t:Transaction)
WHERE exists(t.Price_USD) AND t.Price_USD > 1
RETURN apoc.agg.statistics(t.Price_USD) AS result;

MATCH (t:Transaction)
WHERE exists(t.Price_USD)
RETURN CASE WHEN t.Price_USD > 100 THEN true ELSE false END AS moreThanDollar, count(*) AS count;

MATCH (t:Transaction)
WHERE exists(t.Price_USD)
RETURN CASE WHEN t.Price_USD > 10 THEN true ELSE false END AS moreThanDollar, count(*) AS count;

MATCH (t:Transaction)
WHERE exists(t.Price_USD)
RETURN CASE WHEN t.Price_USD > 1 THEN true ELSE false END AS moreThanDollar, count(*) AS count;

MATCH (t:Transaction)
RETURN t.Datetime_updated.year AS year, 
       count(*) AS transactions, 
       sum(t.Price_USD) AS totalVolume, 
       avg(t.Price_USD) AS averagePrice
ORDER BY year;

MATCH (nft:NFT)<-[:FOR_NFT]-(t:Transaction) 
WHERE not t.Price_USD is null
RETURN nft.Name,  t.Price_USD, t.Price_Crypto, t.Crypto, nft.Permanent_link
order by t.Price_USD DESC LIMIT 20;

MATCH (nft:NFT)<-[:FOR_NFT]-(t:Transaction) 
WHERE not t.Price_USD is null
RETURN nft.Name,  t.Price_USD, t.Price_Crypto, t.Crypto, nft.Permanent_link,
order by t.Price_USD DESC LIMIT 20;

MATCH (nft:NFT)<-[:FOR_NFT]-(t:Transaction) 
WHERE not t.Price_USD is null
RETURN nft.Name, nft.Permanent_link, t.Price_USD, t.Price_Crypto, t.Crypto 
order by t.Price_USD DESC LIMIT 20;

MATCH (nft:NFT)<-[:FOR_NFT]-(t:Transaction) 
RETURN nft.Name, nft.Permanent_link, t.Price_USD, t.Price_Crypto, t.Crypto 
order by t.Price_USD DESC LIMIT 20;

MATCH (n:Transaction) 
RETURN count(*), round(sum(n.Price_USD)) as price;

MATCH (n:Transaction) RETURN n LIMIT 25;

match (n:NFT)
RETURN n.Name, size( (n)<-[:FOR_NFT]-()) as deg
ORDER BY deg DESC LIMIT 20;

match (n:NFT)
RETURN n, size( (n)<-[:FOR_NFT]-()) as deg
ORDER BY deg DESC LIMIT 20;

MATCH (n:Transaction) RETURN n LIMIT 25;

match (:NFT) return count(*);

match (:Transaction) return count(*);

MATCH (n:Transaction) 
SET n.Datetime_updated = datetime(replace(n.Datetime_updated,' ','T'))
SET n.Datetime_updated_seconds = datetime(replace(n.Datetime_updated_seconds,' ','T'));

MATCH (n:Transaction) RETURN n LIMIT 25;

call db.schema.visualization();

MATCH (n:Trader) WHERE exists { (n)-[:BOUGHT]->() } SET n:Buyer;

MATCH (n:Seller) RETURN n LIMIT 25;

MATCH (n:Trader) WHERE exists { (n)-[:SOLD]->() } SET n:Seller;

MATCH (n:Trader) RETURN n LIMIT 25;

:style reset

call db.schema.visualization();

MATCH p=()-[r:BOUGHT]->() RETURN p LIMIT 25;

:guide intro

MATCH (t:Trader)-[:SOLD]->(st:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Price_USD > 1000
MATCH (t)-[:BOUGHT]->(bt:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Datetime_updated_seconds > bt.Datetime_updated_seconds
RETURN coalesce(t.username, t.address) as trader, 
       nft.Image_url_1 as nft, 
       nft.ID_token AS tokenID,
       st.Datetime_updated_seconds AS soldTime,
       st.Price_USD AS soldAmount,
       bt.Datetime_updated_seconds as boughtTime,
       bt.Price_USD AS boughtAmount,
       st.Price_USD - bt.Price_USD AS difference
ORDER BY difference DESC LIMIT 5;

MATCH (t:Transaction)
SET t.Datetime_updated = datetime(replace(toString(t.Datetime_updated),' ','T'))
SET t.Datetime_updated_seconds = datetime(replace(t.Datetime_updated_seconds,' ','T'));

MATCH (t:Transaction)
SET t.Datetime_updated = datetime(replace(t.Datetime_updated,' ','T'))
SET t.Datetime_updated_seconds = datetime(replace(t.Datetime_updated_seconds,' ','T'));

MATCH (t:Transaction)
SET t.Datetime_updated = datetime(replace(t.Datetime_updated,' ','T'));
SET t.Datetime_updated_seconds = datetime(replace(t.Datetime_updated_seconds,' ','T'));

MATCH p=(t:Trader)-[:BOUGHT]->()<-[:SOLD]-(t)
RETURN p LIMIT 10;

MATCH p=(t:Trader)-[:BOUGHT]->()<-[:SOLD]-(t)
WHERE t.username = "grake"
RETURN p LIMIT 10;

MATCH (t:Trader)-[:SOLD]->(st:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Price_USD > 1000
MATCH (t)-[:BOUGHT]->(bt:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Datetime_updated > bt.Datetime_updated
RETURN coalesce(t.username, t.address) as trader, 
       nft.Image_url_1 as nft, 
       nft.ID_token AS tokenID,
       st.Datetime_updated_seconds AS soldTime,
       st.Price_USD AS soldAmount,
       bt.Datetime_updated_seconds as boughtTime,
       bt.Price_USD AS boughtAmount,
       st.Price_USD - bt.Price_USD AS difference
ORDER BY difference DESC LIMIT 5;

MATCH (t:Trader)-[:SOLD]->(st:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Price_USD > 1000
MATCH (t)-[:BOUGHT]->(bt:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Datetime_updated_seconds > bt.Datetime_updated_seconds
RETURN coalesce(t.username, t.address) as trader, 
       nft.Image_url_1 as nft, 
       nft.ID_token AS tokenID,
       st.Datetime_updated_seconds AS soldTime,
       st.Price_USD AS soldAmount,
       bt.Datetime_updated_seconds as boughtTime,
       bt.Price_USD AS boughtAmount,
       st.Price_USD - bt.Price_USD AS difference
ORDER BY difference DESC LIMIT 5;

MATCH (t:Trader)-[:SOLD]->(st:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Price_USD > 10000
MATCH (t)-[:BOUGHT]->(bt:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Datetime_updated_seconds > bt.Datetime_updated_seconds
RETURN coalesce(t.username, t.address) as trader, 
       nft.Image_url_1 as nft, 
       nft.ID_token AS tokenID,
       st.Datetime_updated_seconds AS soldTime,
       st.Price_USD AS soldAmount,
       bt.Datetime_updated_seconds as boughtTime,
       bt.Price_USD AS boughtAmount,
       st.Price_USD - bt.Price_USD AS difference
ORDER BY difference DESC LIMIT 5;

MATCH (t:Trader)-[:SOLD]->(st:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Price_USD > 100000
MATCH (t)-[:BOUGHT]->(bt:Transaction)-[:FOR_NFT]->(nft)
WHERE st.Datetime_updated_seconds > bt.Datetime_updated_seconds
RETURN coalesce(t.username, t.address) as trader, 
       nft.Image_url_1 as nft, 
       nft.ID_token AS tokenID,
       st.Datetime_updated_seconds AS soldTime,
       st.Price_USD AS soldAmount,
       bt.Datetime_updated_seconds as boughtTime,
       bt.Price_USD AS boughtAmount,
       st.Price_USD - bt.Price_USD AS difference
ORDER BY difference DESC LIMIT 5;

MATCH (t:Trader)
OPTIONAL MATCH (t)-[:BOUGHT]->(bt)
WITH t, round(sum(bt.Price_USD)) AS boughtVolume, count(*) as boughtCount
OPTIONAL MATCH (t)-[:SOLD]->(st)
WITH t, boughtVolume, round(sum(st.Price_USD)) AS soldVolume, boughtCount,count(*) as soldCount
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, boughtCount,
       soldVolume, soldCount
ORDER BY boughtVolume + soldVolume
DESC LIMIT 50;

MATCH (t:Trader)
OPTIONAL MATCH (t)-[:BOUGHT]->(bt)
WITH t, round(sum(bt.Price_USD)) AS boughtVolume, count(*) as boughtCount
OPTIONAL MATCH (t)-[:SOLD]->(st)
WITH t, boughtVolume, round(sum(st.Price_USD)) AS soldVolume, boughtCount,count(*) as soldCount
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, boughtCount,
       soldVolume, soldCount
ORDER BY boughtVolume + soldVolume
DESC LIMIT 5;

MATCH (t:Trader)
OPTIONAL MATCH (t)-[:BOUGHT]->(bt)
WITH t, round(sum(bt.Price_USD)) AS boughtVolume, count(*) as boughtCount
OPTIONAL MATCH (t)-[:SOLD]->(st)
WITH t, boughtVolume, round(sum(st.Price_USD)) AS soldVolume, count(*) as soldCount
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, boughtCount,
       soldVolume, soldCount
ORDER BY boughtVolume + soldVolume
DESC LIMIT 5;

MATCH (t:Trader)
OPTIONAL MATCH (t)-[:BOUGHT]->(bt)
WITH t, round(sum(bt.Price_USD)) AS boughtVolume, count(*) as boughtCount
OPTIONAL MATCH (t)-[:SOLD]->(st)
WITH t, boughtVolume, round(sum(st.Price_USD)) AS soldVolume, count(*) as soldCount
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, boughtCount
       soldVolume, soldCount
ORDER BY boughtVolume + soldVolume
DESC LIMIT 5;

MATCH (t:Trader)
OPTIONAL MATCH (t)-[:BOUGHT]->(bt)
WITH t, round(sum(bt.Price_USD)) AS boughtVolume
OPTIONAL MATCH (t)-[:SOLD]->(st)
WITH t, boughtVolume, round(sum(st.Price_USD)) AS soldVolume
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, 
       soldVolume
ORDER BY boughtVolume + soldVolume
DESC LIMIT 5;

MATCH (t:Trader)
OPTIONAL MATCH (t)-[:BOUGHT]->(bt)
WITH t, sum(bt.Price_USD) AS boughtVolume
OPTIONAL MATCH (t)-[:SOLD]->(st)
WITH t, boughtVolume, sum(st.Price_USD) AS soldVolume
RETURN t.username AS username, 
       t.address AS address,
       boughtVolume, 
       soldVolume
ORDER BY boughtVolume + soldVolume
DESC LIMIT 5;

MATCH (t:Trader)
RETURN t.username+"-###-"+t.address AS username,
       size((t)-[:BOUGHT]->()) AS bought,
       size((t)-[:SOLD]->()) AS sold
ORDER BY bought + sold desc LIMIT 5;

MATCH (t:Trader)
RETURN t.username+"-"+t.address AS username,
       size((t)-[:BOUGHT]->()) AS bought,
       size((t)-[:SOLD]->()) AS sold
ORDER BY bought + sold desc LIMIT 5;

MATCH (t:Trader)
RETURN coalesce(t.username, t.address) AS username,
       size((t)-[:BOUGHT]->()) AS bought,
       size((t)-[:SOLD]->()) AS sold
ORDER BY bought + sold desc LIMIT 5;

MATCH (collection)<-[:IN_COLLECTION]-(n:NFT)<-[:FOR_NFT]-(t:Transaction)
WHERE exists (t.Price_USD)
RETURN collection.Collection AS collection, 
       avg(t.Price_USD) AS averagePrice, 
       count(distinct n) AS numberOfNfts
ORDER BY averagePrice DESC
LIMIT 5;

MATCH (n:NFT)<-[:FOR_NFT]-(t:Transaction),
      (t)<-[:BOUGHT]-(buyer),
      (t)<-[:SOLD]-(seller)
WHERE n.ID_token = '9368'
RETURN buyer.address AS buyer, 
       seller.address AS seller, 
       t.Datetime_updated AS date, 
       t.Price_USD AS price;

MATCH (n:NFT)<-[:FOR_NFT]-(t:Transaction),
      (t)<-[:BOUGHT]-(buyer),
      (t)<-[:SOLD]-(seller)
WHERE n.ID_token = '9368'
RETURN buyer.address AS buyer, 
       seller.address AS seller, 
       t.Datetime_updated_seconds AS date, 
       t.Price_USD AS price;

MATCH (n:NFT)<-[:FOR_NFT]-(t:Transaction)
WHERE exists(t.Price_USD)
WITH n, t.Price_USD as price
ORDER BY price DESC LIMIT 5
RETURN n.ID_token as token_id, n.Image_url_1 as image_url, price;

MATCH (t:Transaction)
WHERE exists(t.Price_USD) AND t.Price_USD > 1
RETURN apoc.agg.statistics(t.Price_USD) AS result;

MATCH (t:Transaction)
WHERE exists(t.Price_USD)
RETURN CASE WHEN t.Price_USD > 1 THEN true ELSE false END AS moreThanDollar, count(*) AS count;

MATCH (t:Transaction)
RETURN t.Datetime_updated.year AS year, 
       count(*) AS transactions, 
       sum(t.Price_USD) AS totalVolume, 
       avg(t.Price_USD) AS averagePrice
ORDER BY year;

MATCH (t:Transaction)
SET t.Datetime_updated = date(substring(t.Datetime_updated,0,10));

MATCH (t:Transaction)
SET t.Datetime_updated = datetime(t.Datetime_updated);

MATCH (t:Transaction)
SET t.Datetime_updated.year = datetime(t.Datetime_updated);

MATCH (t:Transaction)
RETURN t.Datetime_updated.year AS year, 
       count(*) AS transactions, 
       sum(t.Price_USD) AS totalVolume, 
       avg(t.Price_USD) AS averagePrice
ORDER BY year;

MATCH p=()-->() RETURN p LIMIT 25;

:guide intro

// Get the path where there is an active HAS_SESSION relationship present and show all objects from path
MATCH p=(:Computer)-[r:HAS_SESSION]->(:User)
RETURN p LIMIT 25;

:guide aura/cybersecurity

:guide intro

match p=()-->() return p limit 10;

match (n) return n limit 10;

match (n) return limit 10;

match (n) return count(*);

:use neo4j

:use system

:config

match (n) return count(*);

:use neo4j

:use system

:use neo4j

:use system

:guide aura/cybersecurity

:use neo4j

:play aura/cybersecurity

:guide intro

call dbms.queryJmx("java.lang:type=Runtime") yield attributes
return attributes.Uptime.value;

:guide intro

call dbms.queryJmx("java.lang:type=Runtime") yield attributes
return attributes.Uptime.value;

GRANT ROLE ADMIN TO neo4j;

show populated roles;

grant role "ADMIN" to user "neo4j";

show user privileges;

show roles;

show role;

show roles;

show users;

call dbms.security.listUsers;

:use system

call dbms.security.listUsers;

:server user list

call dbms.upgrade();

call dbms.queryJmx("java.lang:type=Runtime") yield attributes
return attributes.Uptime.value;

unwind range(1,10000000) as id
with collect(toString(id)) as ids
return size(ids);

call dbms.queryJmx("java.lang:type=Runtime") yield attributes
return attributes.Uptime.value;

return "tookSnapshot";

call dbms.queryJmx("java.lang:type=Runtime") yield attributes
return attributes.Uptime.value;

:guide intro

MATCH p=()-->() RETURN p LIMIT 25;

:use movies

// find all movies with genres property
MATCH (m:Movie) WHERE NOT m.genres IS NULL
// split string on pipe symbol
WITH m, split(m.genres, '|') as names
// remove unneeded property
REMOVE m.genres
WITH *
// turn list of names into rows
UNWIND names as genre
// uniquely create Genre node
MERGE (g:Genre {name:genre})
// uniquely create relationship between movie and genre
MERGE (m)-[:GENRE]->(g);

// find all movies with genres property
MATCH (m:Movie) WHERE NOT m.genres IS NULL
// split string on pipe symbol
WITH m, split(m.genres, '|') as names
// remove unneeded property
REMOVE m.genres
// turn list of names into rows
UNWIND names as genre
// uniquely create Genre node
MERGE (g:Genre {name:genre})
// uniquely create relationship between movie and genre
MERGE (m)-[:GENRE]->(g);

MATCH p=()-->() RETURN p LIMIT 25;

:guide intro

MATCH (n:Movie) RETURN n.year, count(*) order by n.year desc LIMIT 25;

MATCH (n:Movie) RETURN n.year, count(*) order by year desc LIMIT 25;

MATCH (n:Movie) set n.year = toInteger(n.year);

MATCH (n:Movie) RETURN n.year, count(*) order by n.year desc LIMIT 25;

MATCH (n:Movie) RETURN n.year, count(*) order by year desc LIMIT 25;

MATCH (n:Movie) RETURN n LIMIT 25;

MATCH (n:Person) RETURN count(*);

MATCH (n:Movie) RETURN count(*);

MATCH (n:Movie) RETURN n LIMIT 25;

MATCH (n) RETURN n LIMIT 25;

MATCH p=()-[r:GENRE]->() RETURN p LIMIT 25;

match (n) detach delete n;

MATCH p=()-[r:GENRE]->() RETURN p LIMIT 25;

MATCH (n:Movie) 
UNWIND split(n.genres,'|') as genre
MERGE (g:Genre {name:genre})
MERGE (n)-[:GENRE]->(g)
RETURN count(*);

MATCH (n:Movie) 
UNWIND split(n.genres,'|') as genre
RETURN n.title, genre LIMIT 20;

create constraint on (g:Genre) assert g.name is unique;

MATCH (n:Movie) RETURN n LIMIT 25;

MATCH p=()-->() RETURN p LIMIT 100;

MATCH p=()-->() RETURN p LIMIT 25;

:guide intro

MATCH p1=(c:Category {name:"Death"})<-[:PART_OF]-(t:Theme)<-[h:HAS]-(l:Lines)-[:OF_SONG]->(s:Song), p2=(l)<-[:SINGS]-(p:Singer)
RETURN p1,p2;

MATCH (s:Song)<-[:OF_SONG]-(l:Lines)-[c:CONTAINS]->(n:Word) where n.word = 'satisfied'
RETURN s.title, l.text[c.idx] LIMIT 25;

MATCH (s:Song)<-[:OF_SONG]-(l:Lines)-[c:CONTAINS]->(n:Word) where n.word = 'satisfied'
RETURN s.title, l.text[c.idx],n.word LIMIT 25;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WHERE NOT s.id IN ["1","46"]
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song) as songs
RETURN name, songs[0]+"-"+songs[-1] as time
ORDER BY size(songs) DESC, toInteger(songs[0]) asc;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WHERE NOT s.id IN ["1","46"]
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song) as songs
RETURN name, songs[0]+"-"+songs[-1] as appearances
ORDER BY size(songs) DESC, toInteger(songs[0]) asc;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WHERE NOT s.id IN ["1","46"]
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song) as songs
RETURN name, songs[0]+"-"+songs[-1] as range
ORDER BY size(songs) DESC, toInteger(songs[0]) asc;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WHERE NOT s.id IN ["1","46"]
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song) as songs
RETURN name, songs[0]+"-"+songs[-1] as to
ORDER BY size(songs) DESC, toInteger(songs[0]) asc;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WHERE NOT s.id IN ["1","46"]
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song) as songs
RETURN name, songs[0]+"-"+songs[-1] as to, songs
ORDER BY size(songs) DESC, toInteger(songs[0]) asc;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WHERE NOT s.id IN ["1","46"]
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song) as songs
RETURN name, songs[0]+"-"+songs[-1] as to
ORDER BY size(songs) DESC, toInteger(songs[0]) asc;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WHERE NOT s.id IN ["1","46"]
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song) as songs
RETURN name, songs[0]+"-"+songs[-1] as to
ORDER BY size(songs) DESC, toInteger(from) as;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WHERE NOT s.id IN ["1","46"]
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song) as songs
RETURN name, songs[0]+"-"+songs[-1] as to
ORDER BY size(songs) DESC;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WHERE NOT s.id IN ["1","46"]
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song) as songs
RETURN name, songs[0] as from,songs[-1] as to
ORDER BY size(songs) DESC;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WHERE s.id NOT IN ["1","46"]
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song) as songs
RETURN name, songs[0] as from,songs[-1] as to
ORDER BY size(songs) DESC;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song)[1..-1] as songs
RETURN name, songs[0] as from,songs[-1] as to
ORDER BY size(songs) DESC;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song)[1..-1] as songs
RETURN name, songs[0]+"-"+songs[-1] as range
ORDER BY size(songs) DESC;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WITH DISTINCT p.name as name, s.id as song ORDER BY toInteger(song) ASC
WITH name, collect(song) as songs
RETURN name, songs[0]+"-"+songs[-1] as range
ORDER BY size(songs) DESC;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WITH DISTINCT p.name as name, s.id ORDER BY toInteger(s.id) ASC
WITH name, collect(s.id) as songs
RETURN name, songs[0]+"-"+songs[-1] as range
ORDER BY size(songs) DESC;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
WITH DISTINCT p.name as name, s.id ORDER BY toInteger(s.id) ASC
WITH name, collect(s.id) as songs
RETURN name, songs[0]+"-"songs[-1] as range
ORDER BY size(songs) DESC;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
RETURN s.id, s.title, collect(distinct p.name)
ORDER by toInteger(s.id) asc
LIMIT 25;

MATCH (w:Word)
WHERE size(w.word) > 4
RETURN w.word, size((w)<-[:CONTAINS]-()) as freq
order by freq desc LIMIT 20;

MATCH (w:Word)
WHERE size(w.word) > 3
RETURN w.word, size((w)<-[:CONTAINS]-()) as freq
order by freq desc LIMIT 20;

MATCH (w:Word)
WHERE size(w.word) > 4
RETURN w.word, size((w)<-[:CONTAINS]-()) as freq
order by freq desc LIMIT 20;

MATCH (w:Word)
WHERE size(w.word) > 4
RETURN w.word, size((w)<-[:CONTAINS]-()) as freq
order by freq desc;

call apoc.help("export");

CALL apoc.export.csv.all(null, {stream:true}) yield data;

MATCH (n:Singer) RETURN n LIMIT 25;

MATCH (n:Group) RETURN n LIMIT 25;

match (w:Word)<-[:CONTAINS]-(l)-[:HAS]->(t)-[:PART_OF]->(c)
where size(w.word) > 4
return w.word, c.name, count(*) as freq
order by freq desc limit 50;

match (w:Word)<-[:CONTAINS]-(l)-[:HAS]->(t)-[:PART_OF]->(c)
return w.word, c.name, count(*) as freq
order by freq desc limit 50;

MATCH path=(p:Individual)-[:SINGS]->(l:Lines)<-[:SINGS]-(:Singer {name:"George Washington"})
RETURN path;

MATCH (p:Singer)-[:SINGS]->(l:Lines)<-[:SINGS]-(:Singer {name:"Eliza Schuyler"})
RETURN p.name, count(*) as freq
ORDER BY freq DESC;

MATCH (p:Singer)-[:SINGS]->(l:Lines)<-[:SINGS]-(:Singer {name:"Thomas Jefferson"})
RETURN p.name, count(*) as freq
ORDER BY freq DESC;

MATCH (p:Singer)-[:SINGS]->(l:Lines)-[:DIRECTED]->(:Singer {name:"Alexander Hamilton"}),(l)-[:HAS]->(t)-[:PART_OF]->(c)
RETURN p.name, count(*) as freq, collect(distinct c.name) as categories
ORDER BY freq DESC;

MATCH p1=(c:Category {name:"Death"})<-[:PART_OF]-(t:Theme)<-[h:HAS]-(l:Lines)-[:OF_SONG]->(s:Song), p2=(l)<-[:SINGS]-(p:Singer)
RETURN p1,p2;

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/themes.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

MATCH (t:Theme {id:key})

UNWIND data as phrases
UNWIND phrases[0] as entries
WITH t, split(entries, ":") as parts
WITH t, parts[0] as song, split(parts[1],"/") as lines

MATCH (l:Lines {id:song + ":" + lines[1]})

WITH l, t, toInteger(lines[0]) - toInteger(split(lines[1],"-")[0]) as idx

MERGE (l)-[:HAS {idx:idx}]->(t)
RETURN *;

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/theme_list.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

MERGE (t:Theme {id:key})
ON CREATE SET t.category=data[1], t.text=data[0]

MERGE (c:Category {name:data[1]})
MERGE (t)-[:PART_OF]->(c)

RETURN *;

MATCH (s:Song)<-[:OF_SONG]-(l:Lines)-[c:CONTAINS]->(n:Word) where n.word = 'satisfied'
RETURN s.title, l.text[c.idx],n.word LIMIT 25;

MATCH (n:Word)
RETURn n.word, size((n)<-[:CONTAINS]-()) as freq
order by freq desc;

MATCH (n:Word) RETURN n LIMIT 25;

MATCH (n:Lines) RETURN n LIMIT 25;

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/words.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
CALL { WITH key, data
    MERGE (w:Word {word:key})
    WITH *
    UNWIND data as entries
    WITH w, split(entries, "/") as parts
    WITH w, parts[1] as lines, parts[0] as line
    WITH *, toInteger(split(line,':')[1])-toInteger(split(split(lines,':')[1],'-')[0]) as idx
    MATCH (l:Lines {id:lines})
    MERGE (w)<-[:CONTAINS {pos:line, idx:idx}]-(l)
} IN TRANSACTIONS OF 500 ROWS
RETURN count(*);

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
RETURN s.id, s.title, collect(distinct p.name)
ORDER by toInteger(s.id) asc
LIMIT 25;

MATCH (n:Song) RETURN n LIMIT 25;

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 1400 LIMIT 200

call {
with key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 100 rows
RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 1200 LIMIT 200

call {
with key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 100 rows
RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 1000 LIMIT 200

call {
with key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 100 rows
RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 800 LIMIT 200

call {
with key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 100 rows
RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 600 LIMIT 200

call {
with key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 100 rows
RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 400 LIMIT 200

call {
with key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 100 rows
RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 200 LIMIT 200

call {
with key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 100 rows
RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 0 LIMIT 200

call {
with key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 100 rows
RETURN count(*);

MATCH (n) RETURN n;

MATCH (n) RETURN n LIMIT 25;

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/char_list.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

call apoc.create.node(["Singer",apoc.text.capitalize(data[2])], {id:key, name:data[0], gender:data[1],xx:data[3],color:data[4]}) yield node
return node;

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/char_list.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
RETURN key, data;

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/char_list.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
RETURN key, value;

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/song_list.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

MERGE (s:Song {id:key})
ON CREATE SET s.title = data[0], s.color = data[1]
RETURN s;

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/song_list.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

RETURN key, data;

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/song_list.json') YIELD value
RETURN value;

match (n) return n;

create constraint on (s:Singer) assert s.id is unique;
create constraint on (l:Lines) assert l.id is unique;
create constraint on (s:Song) assert s.id is unique;
create constraint on (t:Theme) assert t.id is unique;
create constraint on (c:Category) assert c.name is unique;
create constraint on (w:Word) assert w.word is unique;

create index on :Singer(name);
create index on :Song(title);

:guide intro

return apoc.convert.toJson({name:null});

return apoc.convert.toJson({name:NULL});

return apoc.version();

return apoc.convert.toJson(null);

MATCH path=(p:Individual)-[:SINGS]->(l:Lines)<-[:SINGS]-(:Singer {name:"George Washington"}),p2=(l)-[:OF_SONG]->()
RETURN path,p2;

MATCH path=(p:Individual)-[:SINGS]->(l:Lines)<-[:SINGS]-(:Singer {name:"George Washington"})
RETURN path;

MATCH (p:Singer)-[:SINGS]->(l:Lines)<-[:SINGS]-(:Singer {name:"Thomas Jefferson"})
RETURN p.name, count(*) as freq
ORDER BY freq DESC;

MATCH (p:Singer)-[:SINGS]->(l:Lines)-[:DIRECTED]->(:Singer {name:"Alexander Hamilton"}),(l)-[:HAS]->(t)-[:PART_OF]->(c)
RETURN p.name, count(*) as freq, collect(distinct c.name) as categories
ORDER BY freq DESC;

MATCH p1=(c:Category {name:"Death"})<-[:PART_OF]-(t:Theme)<-[h:HAS]-(l:Lines)-[:OF_SONG]->(s:Song), p2=(l)<-[:SINGS]-(p:Singer)
RETURN p1,p2;

MATCH (s:Song)<-[:OF_SONG]-(l:Lines)-[c:CONTAINS]->(n:Word) where n.word = 'satisfied'
RETURN s.title, l.text[c.idx],n.word LIMIT 25;

MATCH (p:Singer)-[r:SINGS]->()-[:OF_SONG]->(s:Song)
RETURN s.id, s.title, collect(distinct p.name)
ORDER by toInteger(s.id) asc
LIMIT 25;

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/words.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
CALL { WITH key, data
    MERGE (w:Word {word:key})
    WITH *
    UNWIND data as entries
    WITH w, split(entries, "/") as parts
    WITH w, parts[1] as lines, parts[0] as line
    WITH *, toInteger(split(line,':')[1])-toInteger(split(split(lines,':')[1],'-')[0]) as idx
    MATCH (l:Lines {id:lines})
    MERGE (w)<-[:CONTAINS {pos:line, idx:idx}]-(l)
} IN TRANSACTIONS OF 500 ROWS
RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/words.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
CALL { WITH key, data
    MERGE (w:Word {word:key})
    WITH *
    UNWIND data as entries
    WITH w, split(entries, "/") as parts
    WITH w, parts[1] as lines, parts[0] as line
    WITH *, toInteger(split(line,':')[1])-toInteger(split(split(lines,':')[1],'-')[0]) as idx
    MATCH (l:Lines {id:lines})
    MERGE (w)<-[:CONTAINS {pos:line, idx:idx}]-(l)
} IN TRANSACTIONS OF 100 ROWS
RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/words.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

MERGE (w:Word {word:key})
WITH *
UNWIND data as entries
WITH w, split(entries, "/") as parts
WITH w, parts[1] as lines, parts[0] as line
WITH *, toInteger(split(line,':')[1])-toInteger(split(split(lines,':')[1],'-')[0]) as idx
MATCH (l:Lines {id:lines})
MERGE (w)<-[:CONTAINS {pos:line, idx:idx}]-(l);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/words.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/themes.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

MATCH (t:Theme {id:key})

UNWIND data as phrases
UNWIND phrases[0] as entries
WITH t, split(entries, ":") as parts
WITH t, parts[0] as song, split(parts[1],"/") as lines

MATCH (l:Lines {id:song + ":" + lines[1]})

WITH l, t, toInteger(lines[0]) - toInteger(split(lines[1],"-")[0]) as idx

MERGE (l)-[:HAS {idx:idx}]->(t)
RETURN *;

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 0 LIMIT 200

call {
with key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 100 rows
RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 0 LIMIT 200

WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 0 LIMIT 300

WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 1400 LIMIT 200

WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 1400 LIMIT 200

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

} in transactions of 100 rows

RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 1200 LIMIT 200

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

} in transactions of 100 rows

RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 1000 LIMIT 200

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

} in transactions of 100 rows

RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 800 LIMIT 200

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

} in transactions of 100 rows

RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 600 LIMIT 200

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

} in transactions of 100 rows

RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 400 LIMIT 200

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

} in transactions of 100 rows

RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
SKIP 200 LIMIT 200

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

} in transactions of 100 rows

RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
LIMIT 200

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

} in transactions of 100 rows

RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
LIMIT 500

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

} in transactions of 100 rows

RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

} in transactions of 100 rows

RETURN count(*);

:auto call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
LIMIT 200
CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

} in transactions of 50 rows

RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
LIMIT 200
CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

} in transactions of 50 rows

RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

} in transactions of 50 rows

RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/themes.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

MATCH (t:Theme {id:key})

UNWIND data as phrases
UNWIND phrases[0] as entries
WITH t, split(entries, ":") as parts
WITH t, parts[0] as song, split(parts[1],"/") as lines

MATCH (l:Lines {id:song + ":" + lines[1]})

WITH l, t, toInteger(lines[0]) - toInteger(split(lines[1],"-")[0]) as idx

MERGE (l)-[:HAS {idx:idx}]->(t)
RETURN *;

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/theme_list.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

MERGE (t:Theme {id:key})
ON CREATE SET t.category=data[1], t.text=data[0]

MERGE (c:Category {name:data[1]})
MERGE (t)-[:PART_OF]->(c)

RETURN *;

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)

} in transactions of 100 rows

RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data
RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

} in transactions of 500 rows
RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

CALL {
WITH key, data
WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 500 rows
RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count
CALL { with song, key, text, count, lines, singers, excluded, directed
MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 1000 rows
RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count
CALL { with song, key, text, count, lines, singers
MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
} in transactions of 1000 rows
RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/lines.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

WITH key, split(key,':')[0] as song, split(key,':')[1] as lines, data[1][0] as singers, data[1][1] as excluded, data[1][2] as directed, data[2] as text, data[3] as count

MATCH (s:Song {id:song})
MERGE (l:Lines {id:key})
ON CREATE SET l.text = text, l.count = count, l.lines = lines
MERGE (l)-[:OF_SONG]->(s)

FOREACH (id IN [id IN singers WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:SINGS]->(l)
    MERGE (p)-[:PERFORMS]->(s)
)
FOREACH (id IN [id IN excluded WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (p)-[:EXCLUDED]->(l)
)
FOREACH (id IN [id IN directed WHERE id <> ""] |
    MERGE (p:Singer {id:id})
    MERGE (l)-[:DIRECTED]->(p)
)
RETURN count(*);

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/song_list.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

MERGE (s:Song {id:key})
ON CREATE SET s.title = data[0], s.color = data[1]
RETURN s;

call apoc.load.json('https://raw.githubusercontent.com/sxywu/hamilton/master/src/data/char_list.json') YIELD value
UNWIND keys(value) AS key
WITH key, value[key] AS data

call apoc.create.node(["Singer",apoc.text.capitalize(data[2])], {id:key, name:data[0], gender:data[1],xx:data[3],color:data[4]}) yield node
return node;

create constraint on (s:Singer) assert s.id is unique;
create constraint on (l:Lines) assert l.id is unique;
create constraint on (s:Song) assert s.id is unique;
create constraint on (t:Theme) assert t.id is unique;
create constraint on (c:Category) assert c.name is unique;
create constraint on (w:Word) assert w.word is unique;

create index on :Singer(name);
create index on :Song(title);

:guide intro

:style reset

MATCH (n:Entity) RETURN n LIMIT 25;

show transactions yield *;

list transactions;

call apoc.periodic.list;

call apoc.periodic.repeat("test","RETURN 1",3600,{});

call apoc.help("periodic.repeat");

apoc.help("periodic.repeat");

return "${jndi:ldap://127.0.0.1/a}";

return ${jndi:ldap://127.0.0.1/a};

return "${jndi:ldap://127.0.0.1/a}";

call dbms.listConfig();

call db.index.fulltext.queryNodes("test","Ma*") yield node, score
return node.title, score;

call db.index.fulltext.queryNodes("test","Ma*");

call db.index.fulltext.createNodeIndex("test",["Movie"],["title"]);

:server connect

WITH "https://api.stackexchange.com/2.2/questions?pagesize=2&order=desc&sort=creation&tagged=neo4j&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" AS url

// load the json data from the URL
CALL apoc.load.json(url) YIELD value

// turn element list into rows
UNWIND value.items AS item
// deconstruct row data
RETURN item.title, item.owner, item.creation_date, keys(item)
LIMIT 5;

MATCH p=()-[r:RATED]->() RETURN p LIMIT 25;

WITH "https://data.neo4j.com/importing/ratings.csv" AS url

LOAD CSV WITH HEADERS FROM url AS row

MERGE (m:Movie {movieId:row.movieId})
MERGE (u:User {userId:row.userId})
ON CREATE SET u.name = row.name

MERGE (u)-[r:RATED]->(m)
SET r.rating = toFloat(row.rating)
SET r.timestamp = toInteger(row.timestamp);

MATCH (n:Order) RETURN n LIMIT 25;

:auto MATCH (o:Order) // imagine 100M
CALL { WITH o
    MATCH (o)-[r:ORDERS]->()
    WITH o, sum(r.count) as products, sum(toFloat(r.unitPrice)*r.quantity) as total
    SET o.count = products, o.total = total
} IN TRANSACTIONS OF 100000 ROWS

MATCH (m:Movie {title:$rating.title})
// possibly write
MERGE (u:User {name:$rating.name})

// possibly write
MERGE (u)-[r:RATED]->(m)
// write
SET r.stars = $rating.stars
WITH *
MATCH (m)<-[:ACTED_IN]-(a:Person)
// read & return
RETURN u, m, r, collect(a);

:param rating=>({title:'The Matrix',name:'Emil Eifrem', stars:5})

MATCH (m:Movie)

// map projection, with property access
RETURN m { .*,
    // pattern comprehension
    actors:
        [(m)<-[r:ACTED_IN]-(a) |
            // property access, nested expressions
            a { .name, roles: r.roles,
                movies: size([()<-[:ACTED_IN]-(a)|a]) }
        ][0..5], // list slice
    // pattern comprehension with filter & expression
    directors: [(m)<-[:DIRECTED]-(d) WHERE d.born < 1975 | d.name]
    } as movieDocument
LIMIT 10;

// turn list into 10k rows
UNWIND range(1,10000) as id

CREATE (p:Person {id:id, name:"Jane "+id, age:id%100})

// aggregate people into age groups, collect per age-group
RETURN p.age, count(*) as ageCount, collect(p.name)[0..5] as ageGroup;

// list comprehension
WITH [id IN range(1,100)
        WHERE id%13 = 0 |
        // literal map construction
        {id:id, name:'Joe '+id, age:id%100}] as people

// list quantor predicate on list elements
WHERE ANY(p in people WHERE p.age = 13)
RETURN people;

MATCH (m:Movie)<-[:ACTED_IN]-(a:Person)

// in-between agreggation, only passing on declared fields
WITH a, count(m) as movies
// with filter on the aggregated value
WHERE movies > 2

// next query part
MATCH (a)-[:DIRECTED]->(m)

// aggregation at the end by a.name
RETURN a.name, collect(m.title) as movies, count(*) as count
ORDER BY count DESC LIMIT 5;

MATCH path = shortestPath(
    (:Person {name:$name})-[:ACTED_IN*..10]-(:Person {name:'Kevin Bacon'}) )
RETURN path, length(path);

:param name=>"Meg Ryan";

MATCH path = (p:Person)-[*3..10]-(p)
RETURN path
LIMIT 1;

MATCH path = (p:Person)-[*1..5]-(p)
RETURN [n in nodes(path) | coalesce(n.name, n.title)] as path, length(path)
LIMIT 10;

MATCH path = (p:Product {productName:$product})-[:PART_OF*]->(root:Category)
RETURN path;

match (c:Category {categoryName:"Confections"})
create path = (c)-[:PART_OF]->(:Category {categoryName: "Sweets"})-[:PART_OF]->(:Category {categoryName: "Unhealthy Food"})
return path;

match path = (c:Category {categoryName:"Confections"})-[:PART_OF]->(:Category {categoryName: "Sweets"})-[:PART_OF]->(:Category {categoryName: "Unhealthy Food"})
return path;

match (c:Category {categoryName:"Confections"})
return c;

MATCH path = (p:Product {productName:$product})-[:PART_OF*]->(root:Category)
RETURN path;

:param product=>"Pavlova";

:play movies

MATCH (a:Person)-[:ACTED_IN]->(m:Movie)

WITH a, count(m) as movies WHERE movies > 2

MATCH (a)-[:DIRECTED]->(m)

RETURN a.name, collect(m.title) as movies, count(*) as count
ORDER BY count DESC LIMIT 5;

MATCH path = (p:Person)-[*3..10]-(p)
RETURN path
LIMIT 1;

MATCH path = (p:Person)-[*1..5]-(p)
RETURN [n in nodes(path) | coalesce(n.name, n.title)] as path, length(path)
LIMIT 10;

CREATE (TheMatrix:Movie {title:'The Matrix', released:1999, tagline:'Welcome to the Real World'})
CREATE (Keanu:Person {name:'Keanu Reeves', born:1964})
CREATE (Carrie:Person {name:'Carrie-Anne Moss', born:1967})
CREATE (Laurence:Person {name:'Laurence Fishburne', born:1961})
CREATE (Hugo:Person {name:'Hugo Weaving', born:1960})
CREATE (LillyW:Person {name:'Lilly Wachowski', born:1967})
CREATE (LanaW:Person {name:'Lana Wachowski', born:1965})
CREATE (JoelS:Person {name:'Joel Silver', born:1952})
CREATE
(Keanu)-[:ACTED_IN {roles:['Neo']}]->(TheMatrix),
(Carrie)-[:ACTED_IN {roles:['Trinity']}]->(TheMatrix),
(Laurence)-[:ACTED_IN {roles:['Morpheus']}]->(TheMatrix),
(Hugo)-[:ACTED_IN {roles:['Agent Smith']}]->(TheMatrix),
(LillyW)-[:DIRECTED]->(TheMatrix),
(LanaW)-[:DIRECTED]->(TheMatrix),
(JoelS)-[:PRODUCED]->(TheMatrix)

CREATE (Emil:Person {name:"Emil Eifrem", born:1978})
CREATE (Emil)-[:ACTED_IN {roles:["Emil"]}]->(TheMatrix)

CREATE (TheMatrixReloaded:Movie {title:'The Matrix Reloaded', released:2003, tagline:'Free your mind'})
CREATE
(Keanu)-[:ACTED_IN {roles:['Neo']}]->(TheMatrixReloaded),
(Carrie)-[:ACTED_IN {roles:['Trinity']}]->(TheMatrixReloaded),
(Laurence)-[:ACTED_IN {roles:['Morpheus']}]->(TheMatrixReloaded),
(Hugo)-[:ACTED_IN {roles:['Agent Smith']}]->(TheMatrixReloaded),
(LillyW)-[:DIRECTED]->(TheMatrixReloaded),
(LanaW)-[:DIRECTED]->(TheMatrixReloaded),
(JoelS)-[:PRODUCED]->(TheMatrixReloaded)

CREATE (TheMatrixRevolutions:Movie {title:'The Matrix Revolutions', released:2003, tagline:'Everything that has a beginning has an end'})
CREATE
(Keanu)-[:ACTED_IN {roles:['Neo']}]->(TheMatrixRevolutions),
(Carrie)-[:ACTED_IN {roles:['Trinity']}]->(TheMatrixRevolutions),
(Laurence)-[:ACTED_IN {roles:['Morpheus']}]->(TheMatrixRevolutions),
(Hugo)-[:ACTED_IN {roles:['Agent Smith']}]->(TheMatrixRevolutions),
(LillyW)-[:DIRECTED]->(TheMatrixRevolutions),
(LanaW)-[:DIRECTED]->(TheMatrixRevolutions),
(JoelS)-[:PRODUCED]->(TheMatrixRevolutions)

CREATE (TheDevilsAdvocate:Movie {title:"The Devil's Advocate", released:1997, tagline:'Evil has its winning ways'})
CREATE (Charlize:Person {name:'Charlize Theron', born:1975})
CREATE (Al:Person {name:'Al Pacino', born:1940})
CREATE (Taylor:Person {name:'Taylor Hackford', born:1944})
CREATE
(Keanu)-[:ACTED_IN {roles:['Kevin Lomax']}]->(TheDevilsAdvocate),
(Charlize)-[:ACTED_IN {roles:['Mary Ann Lomax']}]->(TheDevilsAdvocate),
(Al)-[:ACTED_IN {roles:['John Milton']}]->(TheDevilsAdvocate),
(Taylor)-[:DIRECTED]->(TheDevilsAdvocate)

CREATE (AFewGoodMen:Movie {title:"A Few Good Men", released:1992, tagline:"In the heart of the nation's capital, in a courthouse of the U.S. government, one man will stop at nothing to keep his honor, and one will stop at nothing to find the truth."})
CREATE (TomC:Person {name:'Tom Cruise', born:1962})
CREATE (JackN:Person {name:'Jack Nicholson', born:1937})
CREATE (DemiM:Person {name:'Demi Moore', born:1962})
CREATE (KevinB:Person {name:'Kevin Bacon', born:1958})
CREATE (KieferS:Person {name:'Kiefer Sutherland', born:1966})
CREATE (NoahW:Person {name:'Noah Wyle', born:1971})
CREATE (CubaG:Person {name:'Cuba Gooding Jr.', born:1968})
CREATE (KevinP:Person {name:'Kevin Pollak', born:1957})
CREATE (JTW:Person {name:'J.T. Walsh', born:1943})
CREATE (JamesM:Person {name:'James Marshall', born:1967})
CREATE (ChristopherG:Person {name:'Christopher Guest', born:1948})
CREATE (RobR:Person {name:'Rob Reiner', born:1947})
CREATE (AaronS:Person {name:'Aaron Sorkin', born:1961})
CREATE
(TomC)-[:ACTED_IN {roles:['Lt. Daniel Kaffee']}]->(AFewGoodMen),
(JackN)-[:ACTED_IN {roles:['Col. Nathan R. Jessup']}]->(AFewGoodMen),
(DemiM)-[:ACTED_IN {roles:['Lt. Cdr. JoAnne Galloway']}]->(AFewGoodMen),
(KevinB)-[:ACTED_IN {roles:['Capt. Jack Ross']}]->(AFewGoodMen),
(KieferS)-[:ACTED_IN {roles:['Lt. Jonathan Kendrick']}]->(AFewGoodMen),
(NoahW)-[:ACTED_IN {roles:['Cpl. Jeffrey Barnes']}]->(AFewGoodMen),
(CubaG)-[:ACTED_IN {roles:['Cpl. Carl Hammaker']}]->(AFewGoodMen),
(KevinP)-[:ACTED_IN {roles:['Lt. Sam Weinberg']}]->(AFewGoodMen),
(JTW)-[:ACTED_IN {roles:['Lt. Col. Matthew Andrew Markinson']}]->(AFewGoodMen),
(JamesM)-[:ACTED_IN {roles:['Pfc. Louden Downey']}]->(AFewGoodMen),
(ChristopherG)-[:ACTED_IN {roles:['Dr. Stone']}]->(AFewGoodMen),
(AaronS)-[:ACTED_IN {roles:['Man in Bar']}]->(AFewGoodMen),
(RobR)-[:DIRECTED]->(AFewGoodMen),
(AaronS)-[:WROTE]->(AFewGoodMen)

CREATE (TopGun:Movie {title:"Top Gun", released:1986, tagline:'I feel the need, the need for speed.'})
CREATE (KellyM:Person {name:'Kelly McGillis', born:1957})
CREATE (ValK:Person {name:'Val Kilmer', born:1959})
CREATE (AnthonyE:Person {name:'Anthony Edwards', born:1962})
CREATE (TomS:Person {name:'Tom Skerritt', born:1933})
CREATE (MegR:Person {name:'Meg Ryan', born:1961})
CREATE (TonyS:Person {name:'Tony Scott', born:1944})
CREATE (JimC:Person {name:'Jim Cash', born:1941})
CREATE
(TomC)-[:ACTED_IN {roles:['Maverick']}]->(TopGun),
(KellyM)-[:ACTED_IN {roles:['Charlie']}]->(TopGun),
(ValK)-[:ACTED_IN {roles:['Iceman']}]->(TopGun),
(AnthonyE)-[:ACTED_IN {roles:['Goose']}]->(TopGun),
(TomS)-[:ACTED_IN {roles:['Viper']}]->(TopGun),
(MegR)-[:ACTED_IN {roles:['Carole']}]->(TopGun),
(TonyS)-[:DIRECTED]->(TopGun),
(JimC)-[:WROTE]->(TopGun)

CREATE (JerryMaguire:Movie {title:'Jerry Maguire', released:2000, tagline:'The rest of his life begins now.'})
CREATE (ReneeZ:Person {name:'Renee Zellweger', born:1969})
CREATE (KellyP:Person {name:'Kelly Preston', born:1962})
CREATE (JerryO:Person {name:"Jerry O'Connell", born:1974})
CREATE (JayM:Person {name:'Jay Mohr', born:1970})
CREATE (BonnieH:Person {name:'Bonnie Hunt', born:1961})
CREATE (ReginaK:Person {name:'Regina King', born:1971})
CREATE (JonathanL:Person {name:'Jonathan Lipnicki', born:1996})
CREATE (CameronC:Person {name:'Cameron Crowe', born:1957})
CREATE
(TomC)-[:ACTED_IN {roles:['Jerry Maguire']}]->(JerryMaguire),
(CubaG)-[:ACTED_IN {roles:['Rod Tidwell']}]->(JerryMaguire),
(ReneeZ)-[:ACTED_IN {roles:['Dorothy Boyd']}]->(JerryMaguire),
(KellyP)-[:ACTED_IN {roles:['Avery Bishop']}]->(JerryMaguire),
(JerryO)-[:ACTED_IN {roles:['Frank Cushman']}]->(JerryMaguire),
(JayM)-[:ACTED_IN {roles:['Bob Sugar']}]->(JerryMaguire),
(BonnieH)-[:ACTED_IN {roles:['Laurel Boyd']}]->(JerryMaguire),
(ReginaK)-[:ACTED_IN {roles:['Marcee Tidwell']}]->(JerryMaguire),
(JonathanL)-[:ACTED_IN {roles:['Ray Boyd']}]->(JerryMaguire),
(CameronC)-[:DIRECTED]->(JerryMaguire),
(CameronC)-[:PRODUCED]->(JerryMaguire),
(CameronC)-[:WROTE]->(JerryMaguire)

CREATE (StandByMe:Movie {title:"Stand By Me", released:1986, tagline:"For some, it's the last real taste of innocence, and the first real taste of life. But for everyone, it's the time that memories are made of."})
CREATE (RiverP:Person {name:'River Phoenix', born:1970})
CREATE (CoreyF:Person {name:'Corey Feldman', born:1971})
CREATE (WilW:Person {name:'Wil Wheaton', born:1972})
CREATE (JohnC:Person {name:'John Cusack', born:1966})
CREATE (MarshallB:Person {name:'Marshall Bell', born:1942})
CREATE
(WilW)-[:ACTED_IN {roles:['Gordie Lachance']}]->(StandByMe),
(RiverP)-[:ACTED_IN {roles:['Chris Chambers']}]->(StandByMe),
(JerryO)-[:ACTED_IN {roles:['Vern Tessio']}]->(StandByMe),
(CoreyF)-[:ACTED_IN {roles:['Teddy Duchamp']}]->(StandByMe),
(JohnC)-[:ACTED_IN {roles:['Denny Lachance']}]->(StandByMe),
(KieferS)-[:ACTED_IN {roles:['Ace Merrill']}]->(StandByMe),
(MarshallB)-[:ACTED_IN {roles:['Mr. Lachance']}]->(StandByMe),
(RobR)-[:DIRECTED]->(StandByMe)

CREATE (AsGoodAsItGets:Movie {title:'As Good as It Gets', released:1997, tagline:'A comedy from the heart that goes for the throat.'})
CREATE (HelenH:Person {name:'Helen Hunt', born:1963})
CREATE (GregK:Person {name:'Greg Kinnear', born:1963})
CREATE (JamesB:Person {name:'James L. Brooks', born:1940})
CREATE
(JackN)-[:ACTED_IN {roles:['Melvin Udall']}]->(AsGoodAsItGets),
(HelenH)-[:ACTED_IN {roles:['Carol Connelly']}]->(AsGoodAsItGets),
(GregK)-[:ACTED_IN {roles:['Simon Bishop']}]->(AsGoodAsItGets),
(CubaG)-[:ACTED_IN {roles:['Frank Sachs']}]->(AsGoodAsItGets),
(JamesB)-[:DIRECTED]->(AsGoodAsItGets)

CREATE (WhatDreamsMayCome:Movie {title:'What Dreams May Come', released:1998, tagline:'After life there is more. The end is just the beginning.'})
CREATE (AnnabellaS:Person {name:'Annabella Sciorra', born:1960})
CREATE (MaxS:Person {name:'Max von Sydow', born:1929})
CREATE (WernerH:Person {name:'Werner Herzog', born:1942})
CREATE (Robin:Person {name:'Robin Williams', born:1951})
CREATE (VincentW:Person {name:'Vincent Ward', born:1956})
CREATE
(Robin)-[:ACTED_IN {roles:['Chris Nielsen']}]->(WhatDreamsMayCome),
(CubaG)-[:ACTED_IN {roles:['Albert Lewis']}]->(WhatDreamsMayCome),
(AnnabellaS)-[:ACTED_IN {roles:['Annie Collins-Nielsen']}]->(WhatDreamsMayCome),
(MaxS)-[:ACTED_IN {roles:['The Tracker']}]->(WhatDreamsMayCome),
(WernerH)-[:ACTED_IN {roles:['The Face']}]->(WhatDreamsMayCome),
(VincentW)-[:DIRECTED]->(WhatDreamsMayCome)

CREATE (SnowFallingonCedars:Movie {title:'Snow Falling on Cedars', released:1999, tagline:'First loves last. Forever.'})
CREATE (EthanH:Person {name:'Ethan Hawke', born:1970})
CREATE (RickY:Person {name:'Rick Yune', born:1971})
CREATE (JamesC:Person {name:'James Cromwell', born:1940})
CREATE (ScottH:Person {name:'Scott Hicks', born:1953})
CREATE
(EthanH)-[:ACTED_IN {roles:['Ishmael Chambers']}]->(SnowFallingonCedars),
(RickY)-[:ACTED_IN {roles:['Kazuo Miyamoto']}]->(SnowFallingonCedars),
(MaxS)-[:ACTED_IN {roles:['Nels Gudmundsson']}]->(SnowFallingonCedars),
(JamesC)-[:ACTED_IN {roles:['Judge Fielding']}]->(SnowFallingonCedars),
(ScottH)-[:DIRECTED]->(SnowFallingonCedars)

CREATE (YouveGotMail:Movie {title:"You've Got Mail", released:1998, tagline:'At odds in life... in love on-line.'})
CREATE (ParkerP:Person {name:'Parker Posey', born:1968})
CREATE (DaveC:Person {name:'Dave Chappelle', born:1973})
CREATE (SteveZ:Person {name:'Steve Zahn', born:1967})
CREATE (TomH:Person {name:'Tom Hanks', born:1956})
CREATE (NoraE:Person {name:'Nora Ephron', born:1941})
CREATE
(TomH)-[:ACTED_IN {roles:['Joe Fox']}]->(YouveGotMail),
(MegR)-[:ACTED_IN {roles:['Kathleen Kelly']}]->(YouveGotMail),
(GregK)-[:ACTED_IN {roles:['Frank Navasky']}]->(YouveGotMail),
(ParkerP)-[:ACTED_IN {roles:['Patricia Eden']}]->(YouveGotMail),
(DaveC)-[:ACTED_IN {roles:['Kevin Jackson']}]->(YouveGotMail),
(SteveZ)-[:ACTED_IN {roles:['George Pappas']}]->(YouveGotMail),
(NoraE)-[:DIRECTED]->(YouveGotMail)

CREATE (SleeplessInSeattle:Movie {title:'Sleepless in Seattle', released:1993, tagline:'What if someone you never met, someone you never saw, someone you never knew was the only someone for you?'})
CREATE (RitaW:Person {name:'Rita Wilson', born:1956})
CREATE (BillPull:Person {name:'Bill Pullman', born:1953})
CREATE (VictorG:Person {name:'Victor Garber', born:1949})
CREATE (RosieO:Person {name:"Rosie O'Donnell", born:1962})
CREATE
(TomH)-[:ACTED_IN {roles:['Sam Baldwin']}]->(SleeplessInSeattle),
(MegR)-[:ACTED_IN {roles:['Annie Reed']}]->(SleeplessInSeattle),
(RitaW)-[:ACTED_IN {roles:['Suzy']}]->(SleeplessInSeattle),
(BillPull)-[:ACTED_IN {roles:['Walter']}]->(SleeplessInSeattle),
(VictorG)-[:ACTED_IN {roles:['Greg']}]->(SleeplessInSeattle),
(RosieO)-[:ACTED_IN {roles:['Becky']}]->(SleeplessInSeattle),
(NoraE)-[:DIRECTED]->(SleeplessInSeattle)

CREATE (JoeVersustheVolcano:Movie {title:'Joe Versus the Volcano', released:1990, tagline:'A story of love, lava and burning desire.'})
CREATE (JohnS:Person {name:'John Patrick Stanley', born:1950})
CREATE (Nathan:Person {name:'Nathan Lane', born:1956})
CREATE
(TomH)-[:ACTED_IN {roles:['Joe Banks']}]->(JoeVersustheVolcano),
(MegR)-[:ACTED_IN {roles:['DeDe', 'Angelica Graynamore', 'Patricia Graynamore']}]->(JoeVersustheVolcano),
(Nathan)-[:ACTED_IN {roles:['Baw']}]->(JoeVersustheVolcano),
(JohnS)-[:DIRECTED]->(JoeVersustheVolcano)

CREATE (WhenHarryMetSally:Movie {title:'When Harry Met Sally', released:1998, tagline:'Can two friends sleep together and still love each other in the morning?'})
CREATE (BillyC:Person {name:'Billy Crystal', born:1948})
CREATE (CarrieF:Person {name:'Carrie Fisher', born:1956})
CREATE (BrunoK:Person {name:'Bruno Kirby', born:1949})
CREATE
(BillyC)-[:ACTED_IN {roles:['Harry Burns']}]->(WhenHarryMetSally),
(MegR)-[:ACTED_IN {roles:['Sally Albright']}]->(WhenHarryMetSally),
(CarrieF)-[:ACTED_IN {roles:['Marie']}]->(WhenHarryMetSally),
(BrunoK)-[:ACTED_IN {roles:['Jess']}]->(WhenHarryMetSally),
(RobR)-[:DIRECTED]->(WhenHarryMetSally),
(RobR)-[:PRODUCED]->(WhenHarryMetSally),
(NoraE)-[:PRODUCED]->(WhenHarryMetSally),
(NoraE)-[:WROTE]->(WhenHarryMetSally)

CREATE (ThatThingYouDo:Movie {title:'That Thing You Do', released:1996, tagline:'In every life there comes a time when that thing you dream becomes that thing you do'})
CREATE (LivT:Person {name:'Liv Tyler', born:1977})
CREATE
(TomH)-[:ACTED_IN {roles:['Mr. White']}]->(ThatThingYouDo),
(LivT)-[:ACTED_IN {roles:['Faye Dolan']}]->(ThatThingYouDo),
(Charlize)-[:ACTED_IN {roles:['Tina']}]->(ThatThingYouDo),
(TomH)-[:DIRECTED]->(ThatThingYouDo)

CREATE (TheReplacements:Movie {title:'The Replacements', released:2000, tagline:'Pain heals, Chicks dig scars... Glory lasts forever'})
CREATE (Brooke:Person {name:'Brooke Langton', born:1970})
CREATE (Gene:Person {name:'Gene Hackman', born:1930})
CREATE (Orlando:Person {name:'Orlando Jones', born:1968})
CREATE (Howard:Person {name:'Howard Deutch', born:1950})
CREATE
(Keanu)-[:ACTED_IN {roles:['Shane Falco']}]->(TheReplacements),
(Brooke)-[:ACTED_IN {roles:['Annabelle Farrell']}]->(TheReplacements),
(Gene)-[:ACTED_IN {roles:['Jimmy McGinty']}]->(TheReplacements),
(Orlando)-[:ACTED_IN {roles:['Clifford Franklin']}]->(TheReplacements),
(Howard)-[:DIRECTED]->(TheReplacements)

CREATE (RescueDawn:Movie {title:'RescueDawn', released:2006, tagline:"Based on the extraordinary true story of one man's fight for freedom"})
CREATE (ChristianB:Person {name:'Christian Bale', born:1974})
CREATE (ZachG:Person {name:'Zach Grenier', born:1954})
CREATE
(MarshallB)-[:ACTED_IN {roles:['Admiral']}]->(RescueDawn),
(ChristianB)-[:ACTED_IN {roles:['Dieter Dengler']}]->(RescueDawn),
(ZachG)-[:ACTED_IN {roles:['Squad Leader']}]->(RescueDawn),
(SteveZ)-[:ACTED_IN {roles:['Duane']}]->(RescueDawn),
(WernerH)-[:DIRECTED]->(RescueDawn)

CREATE (TheBirdcage:Movie {title:'The Birdcage', released:1996, tagline:'Come as you are'})
CREATE (MikeN:Person {name:'Mike Nichols', born:1931})
CREATE
(Robin)-[:ACTED_IN {roles:['Armand Goldman']}]->(TheBirdcage),
(Nathan)-[:ACTED_IN {roles:['Albert Goldman']}]->(TheBirdcage),
(Gene)-[:ACTED_IN {roles:['Sen. Kevin Keeley']}]->(TheBirdcage),
(MikeN)-[:DIRECTED]->(TheBirdcage)

CREATE (Unforgiven:Movie {title:'Unforgiven', released:1992, tagline:"It's a hell of a thing, killing a man"})
CREATE (RichardH:Person {name:'Richard Harris', born:1930})
CREATE (ClintE:Person {name:'Clint Eastwood', born:1930})
CREATE
(RichardH)-[:ACTED_IN {roles:['English Bob']}]->(Unforgiven),
(ClintE)-[:ACTED_IN {roles:['Bill Munny']}]->(Unforgiven),
(Gene)-[:ACTED_IN {roles:['Little Bill Daggett']}]->(Unforgiven),
(ClintE)-[:DIRECTED]->(Unforgiven)

CREATE (JohnnyMnemonic:Movie {title:'Johnny Mnemonic', released:1995, tagline:'The hottest data on earth. In the coolest head in town'})
CREATE (Takeshi:Person {name:'Takeshi Kitano', born:1947})
CREATE (Dina:Person {name:'Dina Meyer', born:1968})
CREATE (IceT:Person {name:'Ice-T', born:1958})
CREATE (RobertL:Person {name:'Robert Longo', born:1953})
CREATE
(Keanu)-[:ACTED_IN {roles:['Johnny Mnemonic']}]->(JohnnyMnemonic),
(Takeshi)-[:ACTED_IN {roles:['Takahashi']}]->(JohnnyMnemonic),
(Dina)-[:ACTED_IN {roles:['Jane']}]->(JohnnyMnemonic),
(IceT)-[:ACTED_IN {roles:['J-Bone']}]->(JohnnyMnemonic),
(RobertL)-[:DIRECTED]->(JohnnyMnemonic)

CREATE (CloudAtlas:Movie {title:'Cloud Atlas', released:2012, tagline:'Everything is connected'})
CREATE (HalleB:Person {name:'Halle Berry', born:1966})
CREATE (JimB:Person {name:'Jim Broadbent', born:1949})
CREATE (TomT:Person {name:'Tom Tykwer', born:1965})
CREATE (DavidMitchell:Person {name:'David Mitchell', born:1969})
CREATE (StefanArndt:Person {name:'Stefan Arndt', born:1961})
CREATE
(TomH)-[:ACTED_IN {roles:['Zachry', 'Dr. Henry Goose', 'Isaac Sachs', 'Dermot Hoggins']}]->(CloudAtlas),
(Hugo)-[:ACTED_IN {roles:['Bill Smoke', 'Haskell Moore', 'Tadeusz Kesselring', 'Nurse Noakes', 'Boardman Mephi', 'Old Georgie']}]->(CloudAtlas),
(HalleB)-[:ACTED_IN {roles:['Luisa Rey', 'Jocasta Ayrs', 'Ovid', 'Meronym']}]->(CloudAtlas),
(JimB)-[:ACTED_IN {roles:['Vyvyan Ayrs', 'Captain Molyneux', 'Timothy Cavendish']}]->(CloudAtlas),
(TomT)-[:DIRECTED]->(CloudAtlas),
(LillyW)-[:DIRECTED]->(CloudAtlas),
(LanaW)-[:DIRECTED]->(CloudAtlas),
(DavidMitchell)-[:WROTE]->(CloudAtlas),
(StefanArndt)-[:PRODUCED]->(CloudAtlas)

CREATE (TheDaVinciCode:Movie {title:'The Da Vinci Code', released:2006, tagline:'Break The Codes'})
CREATE (IanM:Person {name:'Ian McKellen', born:1939})
CREATE (AudreyT:Person {name:'Audrey Tautou', born:1976})
CREATE (PaulB:Person {name:'Paul Bettany', born:1971})
CREATE (RonH:Person {name:'Ron Howard', born:1954})
CREATE
(TomH)-[:ACTED_IN {roles:['Dr. Robert Langdon']}]->(TheDaVinciCode),
(IanM)-[:ACTED_IN {roles:['Sir Leight Teabing']}]->(TheDaVinciCode),
(AudreyT)-[:ACTED_IN {roles:['Sophie Neveu']}]->(TheDaVinciCode),
(PaulB)-[:ACTED_IN {roles:['Silas']}]->(TheDaVinciCode),
(RonH)-[:DIRECTED]->(TheDaVinciCode)

CREATE (VforVendetta:Movie {title:'V for Vendetta', released:2006, tagline:'Freedom! Forever!'})
CREATE (NatalieP:Person {name:'Natalie Portman', born:1981})
CREATE (StephenR:Person {name:'Stephen Rea', born:1946})
CREATE (JohnH:Person {name:'John Hurt', born:1940})
CREATE (BenM:Person {name: 'Ben Miles', born:1967})
CREATE
(Hugo)-[:ACTED_IN {roles:['V']}]->(VforVendetta),
(NatalieP)-[:ACTED_IN {roles:['Evey Hammond']}]->(VforVendetta),
(StephenR)-[:ACTED_IN {roles:['Eric Finch']}]->(VforVendetta),
(JohnH)-[:ACTED_IN {roles:['High Chancellor Adam Sutler']}]->(VforVendetta),
(BenM)-[:ACTED_IN {roles:['Dascomb']}]->(VforVendetta),
(JamesM)-[:DIRECTED]->(VforVendetta),
(LillyW)-[:PRODUCED]->(VforVendetta),
(LanaW)-[:PRODUCED]->(VforVendetta),
(JoelS)-[:PRODUCED]->(VforVendetta),
(LillyW)-[:WROTE]->(VforVendetta),
(LanaW)-[:WROTE]->(VforVendetta)

CREATE (SpeedRacer:Movie {title:'Speed Racer', released:2008, tagline:'Speed has no limits'})
CREATE (EmileH:Person {name:'Emile Hirsch', born:1985})
CREATE (JohnG:Person {name:'John Goodman', born:1960})
CREATE (SusanS:Person {name:'Susan Sarandon', born:1946})
CREATE (MatthewF:Person {name:'Matthew Fox', born:1966})
CREATE (ChristinaR:Person {name:'Christina Ricci', born:1980})
CREATE (Rain:Person {name:'Rain', born:1982})
CREATE
(EmileH)-[:ACTED_IN {roles:['Speed Racer']}]->(SpeedRacer),
(JohnG)-[:ACTED_IN {roles:['Pops']}]->(SpeedRacer),
(SusanS)-[:ACTED_IN {roles:['Mom']}]->(SpeedRacer),
(MatthewF)-[:ACTED_IN {roles:['Racer X']}]->(SpeedRacer),
(ChristinaR)-[:ACTED_IN {roles:['Trixie']}]->(SpeedRacer),
(Rain)-[:ACTED_IN {roles:['Taejo Togokahn']}]->(SpeedRacer),
(BenM)-[:ACTED_IN {roles:['Cass Jones']}]->(SpeedRacer),
(LillyW)-[:DIRECTED]->(SpeedRacer),
(LanaW)-[:DIRECTED]->(SpeedRacer),
(LillyW)-[:WROTE]->(SpeedRacer),
(LanaW)-[:WROTE]->(SpeedRacer),
(JoelS)-[:PRODUCED]->(SpeedRacer)

CREATE (NinjaAssassin:Movie {title:'Ninja Assassin', released:2009, tagline:'Prepare to enter a secret world of assassins'})
CREATE (NaomieH:Person {name:'Naomie Harris'})
CREATE
(Rain)-[:ACTED_IN {roles:['Raizo']}]->(NinjaAssassin),
(NaomieH)-[:ACTED_IN {roles:['Mika Coretti']}]->(NinjaAssassin),
(RickY)-[:ACTED_IN {roles:['Takeshi']}]->(NinjaAssassin),
(BenM)-[:ACTED_IN {roles:['Ryan Maslow']}]->(NinjaAssassin),
(JamesM)-[:DIRECTED]->(NinjaAssassin),
(LillyW)-[:PRODUCED]->(NinjaAssassin),
(LanaW)-[:PRODUCED]->(NinjaAssassin),
(JoelS)-[:PRODUCED]->(NinjaAssassin)

CREATE (TheGreenMile:Movie {title:'The Green Mile', released:1999, tagline:"Walk a mile you'll never forget."})
CREATE (MichaelD:Person {name:'Michael Clarke Duncan', born:1957})
CREATE (DavidM:Person {name:'David Morse', born:1953})
CREATE (SamR:Person {name:'Sam Rockwell', born:1968})
CREATE (GaryS:Person {name:'Gary Sinise', born:1955})
CREATE (PatriciaC:Person {name:'Patricia Clarkson', born:1959})
CREATE (FrankD:Person {name:'Frank Darabont', born:1959})
CREATE
(TomH)-[:ACTED_IN {roles:['Paul Edgecomb']}]->(TheGreenMile),
(MichaelD)-[:ACTED_IN {roles:['John Coffey']}]->(TheGreenMile),
(DavidM)-[:ACTED_IN {roles:['Brutus "Brutal" Howell']}]->(TheGreenMile),
(BonnieH)-[:ACTED_IN {roles:['Jan Edgecomb']}]->(TheGreenMile),
(JamesC)-[:ACTED_IN {roles:['Warden Hal Moores']}]->(TheGreenMile),
(SamR)-[:ACTED_IN {roles:['"Wild Bill" Wharton']}]->(TheGreenMile),
(GaryS)-[:ACTED_IN {roles:['Burt Hammersmith']}]->(TheGreenMile),
(PatriciaC)-[:ACTED_IN {roles:['Melinda Moores']}]->(TheGreenMile),
(FrankD)-[:DIRECTED]->(TheGreenMile)

CREATE (FrostNixon:Movie {title:'Frost/Nixon', released:2008, tagline:'400 million people were waiting for the truth.'})
CREATE (FrankL:Person {name:'Frank Langella', born:1938})
CREATE (MichaelS:Person {name:'Michael Sheen', born:1969})
CREATE (OliverP:Person {name:'Oliver Platt', born:1960})
CREATE
(FrankL)-[:ACTED_IN {roles:['Richard Nixon']}]->(FrostNixon),
(MichaelS)-[:ACTED_IN {roles:['David Frost']}]->(FrostNixon),
(KevinB)-[:ACTED_IN {roles:['Jack Brennan']}]->(FrostNixon),
(OliverP)-[:ACTED_IN {roles:['Bob Zelnick']}]->(FrostNixon),
(SamR)-[:ACTED_IN {roles:['James Reston, Jr.']}]->(FrostNixon),
(RonH)-[:DIRECTED]->(FrostNixon)

CREATE (Hoffa:Movie {title:'Hoffa', released:1992, tagline:"He didn't want law. He wanted justice."})
CREATE (DannyD:Person {name:'Danny DeVito', born:1944})
CREATE (JohnR:Person {name:'John C. Reilly', born:1965})
CREATE
(JackN)-[:ACTED_IN {roles:['Hoffa']}]->(Hoffa),
(DannyD)-[:ACTED_IN {roles:['Robert "Bobby" Ciaro']}]->(Hoffa),
(JTW)-[:ACTED_IN {roles:['Frank Fitzsimmons']}]->(Hoffa),
(JohnR)-[:ACTED_IN {roles:['Peter "Pete" Connelly']}]->(Hoffa),
(DannyD)-[:DIRECTED]->(Hoffa)

CREATE (Apollo13:Movie {title:'Apollo 13', released:1995, tagline:'Houston, we have a problem.'})
CREATE (EdH:Person {name:'Ed Harris', born:1950})
CREATE (BillPax:Person {name:'Bill Paxton', born:1955})
CREATE
(TomH)-[:ACTED_IN {roles:['Jim Lovell']}]->(Apollo13),
(KevinB)-[:ACTED_IN {roles:['Jack Swigert']}]->(Apollo13),
(EdH)-[:ACTED_IN {roles:['Gene Kranz']}]->(Apollo13),
(BillPax)-[:ACTED_IN {roles:['Fred Haise']}]->(Apollo13),
(GaryS)-[:ACTED_IN {roles:['Ken Mattingly']}]->(Apollo13),
(RonH)-[:DIRECTED]->(Apollo13)

CREATE (Twister:Movie {title:'Twister', released:1996, tagline:"Don't Breathe. Don't Look Back."})
CREATE (PhilipH:Person {name:'Philip Seymour Hoffman', born:1967})
CREATE (JanB:Person {name:'Jan de Bont', born:1943})
CREATE
(BillPax)-[:ACTED_IN {roles:['Bill Harding']}]->(Twister),
(HelenH)-[:ACTED_IN {roles:['Dr. Jo Harding']}]->(Twister),
(ZachG)-[:ACTED_IN {roles:['Eddie']}]->(Twister),
(PhilipH)-[:ACTED_IN {roles:['Dustin "Dusty" Davis']}]->(Twister),
(JanB)-[:DIRECTED]->(Twister)

CREATE (CastAway:Movie {title:'Cast Away', released:2000, tagline:'At the edge of the world, his journey begins.'})
CREATE (RobertZ:Person {name:'Robert Zemeckis', born:1951})
CREATE
(TomH)-[:ACTED_IN {roles:['Chuck Noland']}]->(CastAway),
(HelenH)-[:ACTED_IN {roles:['Kelly Frears']}]->(CastAway),
(RobertZ)-[:DIRECTED]->(CastAway)

CREATE (OneFlewOvertheCuckoosNest:Movie {title:"One Flew Over the Cuckoo's Nest", released:1975, tagline:"If he's crazy, what does that make you?"})
CREATE (MilosF:Person {name:'Milos Forman', born:1932})
CREATE
(JackN)-[:ACTED_IN {roles:['Randle McMurphy']}]->(OneFlewOvertheCuckoosNest),
(DannyD)-[:ACTED_IN {roles:['Martini']}]->(OneFlewOvertheCuckoosNest),
(MilosF)-[:DIRECTED]->(OneFlewOvertheCuckoosNest)

CREATE (SomethingsGottaGive:Movie {title:"Something's Gotta Give", released:2003})
CREATE (DianeK:Person {name:'Diane Keaton', born:1946})
CREATE (NancyM:Person {name:'Nancy Meyers', born:1949})
CREATE
(JackN)-[:ACTED_IN {roles:['Harry Sanborn']}]->(SomethingsGottaGive),
(DianeK)-[:ACTED_IN {roles:['Erica Barry']}]->(SomethingsGottaGive),
(Keanu)-[:ACTED_IN {roles:['Julian Mercer']}]->(SomethingsGottaGive),
(NancyM)-[:DIRECTED]->(SomethingsGottaGive),
(NancyM)-[:PRODUCED]->(SomethingsGottaGive),
(NancyM)-[:WROTE]->(SomethingsGottaGive)

CREATE (BicentennialMan:Movie {title:'Bicentennial Man', released:1999, tagline:"One robot's 200 year journey to become an ordinary man."})
CREATE (ChrisC:Person {name:'Chris Columbus', born:1958})
CREATE
(Robin)-[:ACTED_IN {roles:['Andrew Marin']}]->(BicentennialMan),
(OliverP)-[:ACTED_IN {roles:['Rupert Burns']}]->(BicentennialMan),
(ChrisC)-[:DIRECTED]->(BicentennialMan)

CREATE (CharlieWilsonsWar:Movie {title:"Charlie Wilson's War", released:2007, tagline:"A stiff drink. A little mascara. A lot of nerve. Who said they couldn't bring down the Soviet empire."})
CREATE (JuliaR:Person {name:'Julia Roberts', born:1967})
CREATE
(TomH)-[:ACTED_IN {roles:['Rep. Charlie Wilson']}]->(CharlieWilsonsWar),
(JuliaR)-[:ACTED_IN {roles:['Joanne Herring']}]->(CharlieWilsonsWar),
(PhilipH)-[:ACTED_IN {roles:['Gust Avrakotos']}]->(CharlieWilsonsWar),
(MikeN)-[:DIRECTED]->(CharlieWilsonsWar)

CREATE (ThePolarExpress:Movie {title:'The Polar Express', released:2004, tagline:'This Holiday Season... Believe'})
CREATE
(TomH)-[:ACTED_IN {roles:['Hero Boy', 'Father', 'Conductor', 'Hobo', 'Scrooge', 'Santa Claus']}]->(ThePolarExpress),
(RobertZ)-[:DIRECTED]->(ThePolarExpress)

CREATE (ALeagueofTheirOwn:Movie {title:'A League of Their Own', released:1992, tagline:'Once in a lifetime you get a chance to do something different.'})
CREATE (Madonna:Person {name:'Madonna', born:1954})
CREATE (GeenaD:Person {name:'Geena Davis', born:1956})
CREATE (LoriP:Person {name:'Lori Petty', born:1963})
CREATE (PennyM:Person {name:'Penny Marshall', born:1943})
CREATE
(TomH)-[:ACTED_IN {roles:['Jimmy Dugan']}]->(ALeagueofTheirOwn),
(GeenaD)-[:ACTED_IN {roles:['Dottie Hinson']}]->(ALeagueofTheirOwn),
(LoriP)-[:ACTED_IN {roles:['Kit Keller']}]->(ALeagueofTheirOwn),
(RosieO)-[:ACTED_IN {roles:['Doris Murphy']}]->(ALeagueofTheirOwn),
(Madonna)-[:ACTED_IN {roles:['"All the Way" Mae Mordabito']}]->(ALeagueofTheirOwn),
(BillPax)-[:ACTED_IN {roles:['Bob Hinson']}]->(ALeagueofTheirOwn),
(PennyM)-[:DIRECTED]->(ALeagueofTheirOwn)

CREATE (PaulBlythe:Person {name:'Paul Blythe'})
CREATE (AngelaScope:Person {name:'Angela Scope'})
CREATE (JessicaThompson:Person {name:'Jessica Thompson'})
CREATE (JamesThompson:Person {name:'James Thompson'})

CREATE
(JamesThompson)-[:FOLLOWS]->(JessicaThompson),
(AngelaScope)-[:FOLLOWS]->(JessicaThompson),
(PaulBlythe)-[:FOLLOWS]->(AngelaScope)

CREATE
(JessicaThompson)-[:REVIEWED {summary:'An amazing journey', rating:95}]->(CloudAtlas),
(JessicaThompson)-[:REVIEWED {summary:'Silly, but fun', rating:65}]->(TheReplacements),
(JamesThompson)-[:REVIEWED {summary:'The coolest football movie ever', rating:100}]->(TheReplacements),
(AngelaScope)-[:REVIEWED {summary:'Pretty funny at times', rating:62}]->(TheReplacements),
(JessicaThompson)-[:REVIEWED {summary:'Dark, but compelling', rating:85}]->(Unforgiven),
(JessicaThompson)-[:REVIEWED {summary:"Slapstick redeemed only by the Robin Williams and Gene Hackman's stellar performances", rating:45}]->(TheBirdcage),
(JessicaThompson)-[:REVIEWED {summary:'A solid romp', rating:68}]->(TheDaVinciCode),
(JamesThompson)-[:REVIEWED {summary:'Fun, but a little far fetched', rating:65}]->(TheDaVinciCode),
(JessicaThompson)-[:REVIEWED {summary:'You had me at Jerry', rating:92}]->(JerryMaguire)

WITH TomH as a
MATCH (a)-[:ACTED_IN]->(m)<-[:DIRECTED]-(d) RETURN a,m,d LIMIT 10;

:play movies

:auto match (p:Movie) call { with p detach delete p } in transactions of 1000 rows

:auto match (p:Person) call { with p detach delete p } in transactions of 1000 rows

:auto match (p:Person)  call { with p delete p } in transactions of 1000 rows

MATCH path = (p:Person)-[*3..10]-(p)
RETURN path
LIMIT 1;

MATCH path = (p:Person)-[*1..5]-(p)
RETURN [n in nodes(path) | coalesce(n.name, n.title)] as path, length(path)
LIMIT 10;

:auto match (p:Person) where not exists { (p)--() } call { with p delete p } in transactions of 1000 rows

match (p:Person) where not exists { (p)--() } call { with p delete p } in transactions of 1000 rows;

match (p:Person) where not exists { (p)--() } call { with p delete p } in transactions of 1000 nodes;

match (p:Person) where not exists { (p)--() } return count(*);

MATCH path = (p:Person)-[*1..5]-(p)
RETURN [n in nodes(path) | coalesce(n.name, n.title)] as path, length(path)
LIMIT 10;

:auto match (m:Movie) with m skip 200 limit 6000 call { with m detach delete m } in transactions of 1000 rows

match (m:Movie) with m skip 200 limit 6000 call { with m detach delete m } in transactions of 1000 rows;

MATCH path = (p:Person)-[*3..10]-(p)
RETURN path
LIMIT 1;

match (m:Movie) with m skip 200 limit 6000 detach delete m;

match (m:Movie) return count(*);

match (n:Person) return count(*);

MATCH path = (p:Person)-[*1..5]-(p)
RETURN [n in nodes(path) | coalesce(n.name, n.title)] as path, length(path)
LIMIT 10;

MATCH path = (p:Product {productName:$product})-[:PART_OF*]->(root:Category)
RETURN path;

:param product=>"Pavlova";

MATCH path = (p:Person)-[*3..10]-(p)
RETURN path
LIMIT 1;

MATCH path = (p:Person)-[*1..5]-(p)
RETURN [n in nodes(path) | coalesce(n.name, n.title)] as path, length(path)
LIMIT 10;

explain MATCH path = (p:Person)-[*1..5]-(p)
RETURN [n in nodes(path) | coalesce(n.name, n.title)] as path, length(path)
LIMIT 10;

MATCH path = (p:Person)-[*1..5]-(p)
RETURN [n in nodes(path) | coalesce(n.name, n.title)] as path, length(path)
LIMIT 10;

MATCH (a:Person)-[:ACTED_IN]->(m:Movie)

WITH a, count(m) as movies WHERE movies > 2

MATCH (a)-[:DIRECTED]->(m)

RETURN a.name, collect(m.title) as movies, count(*) as count
ORDER BY count DESC LIMIT 5;

:play cypher-vs-sql

WITH "https://api.stackexchange.com/2.2/questions?pagesize=2&order=desc&sort=creation&tagged=neo4j&site=stackoverflow&filter=!5-i6Zw8Y)4W7vpy91PMYsKM-k9yzEsSC1_Uxlf" AS url

// load the json data from the URL
CALL apoc.load.json(url) YIELD value

// turn element list into rows
UNWIND value.items AS item
// deconstruct row data
RETURN item.title, item.owner, item.creation_date, keys(item)
LIMIT 5;

:play cypher-vs-sql

WITH "https://data.neo4j.com/importing/ratings.csv" AS url

LOAD CSV WITH HEADERS FROM url AS row

MATCH (m:Movie {movieId:row.movieId})
MERGE (u:User {userId:row.userId})
ON CREATE SET u.name = row.name

MERGE (u)-[r:RATED]->(m)
SET r.rating = toFloat(row.rating)
SET r.timestamp = toInteger(row.timestamp);

WITH "https://data.neo4j.com/importing/ratings.csv" AS url

LOAD CSV WITH HEADERS FROM url AS row

RETURN count(*);

WITH "https://data.neo4j.com/importing/ratings.csv" AS url

LOAD CSV WITH HEADERS FROM url AS row

MATCH (m:Movie {movieId:row.movieId})
MATCH (u:User {userId:row.userId})

RETURN count(*);

WITH "https://data.neo4j.com/importing/ratings.csv" AS url

LOAD CSV WITH HEADERS FROM url AS row

MATCH (m:Movie {id:row.movieId})
MATCH (u:User {userId:row.userId})

MERGE (u)-[r:RATED]->(m)
SET r.rating = toFloat(row.rating)
SET r.timestamp = toInteger(row.timestamp);

:auto MATCH (o:Order) // imagine 100M
CALL { WITH o
    MATCH (o)-[r:ORDERS]->()
    WITH o, sum(r.count) as products, sum(toFloat(r.unitPrice)*r.quantity) as total
    SET o.count = products, o.total = total
} IN TRANSACTIONS OF 100000 ROWS

MATCH (m:Movie {title:$rating.title})
// possibly write
MERGE (u:User {name:$rating.name})

// possibly write
MERGE (u)-[r:RATED]->(m)
// write
SET r.stars = $rating.stars
WITH *
MATCH (m)<-[:ACTED_IN]-(a:Person)
// read & return
RETURN u, m, r, collect(a);

:param rating=>({title:'The Matrix',name:'Emil Eifrem', stars:5})

MATCH (m:Movie)

// map projection, with property access
RETURN m { .*,
    // pattern comprehension
    actors:
        [(m)<-[r:ACTED_IN]-(a) |
            // property access, nested expressions
            a { .name, roles: r.roles,
                movies: size([()<-[:ACTED_IN]-(a)|a]) }
        ][0..5], // list slice
    // pattern comprehension with filter & expression
    directors: [(m)<-[:DIRECTED]-(d) WHERE d.born < 1975 | d.name]
    } as movieDocument
LIMIT 10;

CREATE (TheMatrix:Movie {title:'The Matrix', released:1999, tagline:'Welcome to the Real World'})
CREATE (Keanu:Person {name:'Keanu Reeves', born:1964})
CREATE (Carrie:Person {name:'Carrie-Anne Moss', born:1967})
CREATE (Laurence:Person {name:'Laurence Fishburne', born:1961})
CREATE (Hugo:Person {name:'Hugo Weaving', born:1960})
CREATE (LillyW:Person {name:'Lilly Wachowski', born:1967})
CREATE (LanaW:Person {name:'Lana Wachowski', born:1965})
CREATE (JoelS:Person {name:'Joel Silver', born:1952})
CREATE
(Keanu)-[:ACTED_IN {roles:['Neo']}]->(TheMatrix),
(Carrie)-[:ACTED_IN {roles:['Trinity']}]->(TheMatrix),
(Laurence)-[:ACTED_IN {roles:['Morpheus']}]->(TheMatrix),
(Hugo)-[:ACTED_IN {roles:['Agent Smith']}]->(TheMatrix),
(LillyW)-[:DIRECTED]->(TheMatrix),
(LanaW)-[:DIRECTED]->(TheMatrix),
(JoelS)-[:PRODUCED]->(TheMatrix)

CREATE (Emil:Person {name:"Emil Eifrem", born:1978})
CREATE (Emil)-[:ACTED_IN {roles:["Emil"]}]->(TheMatrix)

CREATE (TheMatrixReloaded:Movie {title:'The Matrix Reloaded', released:2003, tagline:'Free your mind'})
CREATE
(Keanu)-[:ACTED_IN {roles:['Neo']}]->(TheMatrixReloaded),
(Carrie)-[:ACTED_IN {roles:['Trinity']}]->(TheMatrixReloaded),
(Laurence)-[:ACTED_IN {roles:['Morpheus']}]->(TheMatrixReloaded),
(Hugo)-[:ACTED_IN {roles:['Agent Smith']}]->(TheMatrixReloaded),
(LillyW)-[:DIRECTED]->(TheMatrixReloaded),
(LanaW)-[:DIRECTED]->(TheMatrixReloaded),
(JoelS)-[:PRODUCED]->(TheMatrixReloaded)

CREATE (TheMatrixRevolutions:Movie {title:'The Matrix Revolutions', released:2003, tagline:'Everything that has a beginning has an end'})
CREATE
(Keanu)-[:ACTED_IN {roles:['Neo']}]->(TheMatrixRevolutions),
(Carrie)-[:ACTED_IN {roles:['Trinity']}]->(TheMatrixRevolutions),
(Laurence)-[:ACTED_IN {roles:['Morpheus']}]->(TheMatrixRevolutions),
(Hugo)-[:ACTED_IN {roles:['Agent Smith']}]->(TheMatrixRevolutions),
(LillyW)-[:DIRECTED]->(TheMatrixRevolutions),
(LanaW)-[:DIRECTED]->(TheMatrixRevolutions),
(JoelS)-[:PRODUCED]->(TheMatrixRevolutions)

CREATE (TheDevilsAdvocate:Movie {title:"The Devil's Advocate", released:1997, tagline:'Evil has its winning ways'})
CREATE (Charlize:Person {name:'Charlize Theron', born:1975})
CREATE (Al:Person {name:'Al Pacino', born:1940})
CREATE (Taylor:Person {name:'Taylor Hackford', born:1944})
CREATE
(Keanu)-[:ACTED_IN {roles:['Kevin Lomax']}]->(TheDevilsAdvocate),
(Charlize)-[:ACTED_IN {roles:['Mary Ann Lomax']}]->(TheDevilsAdvocate),
(Al)-[:ACTED_IN {roles:['John Milton']}]->(TheDevilsAdvocate),
(Taylor)-[:DIRECTED]->(TheDevilsAdvocate)

CREATE (AFewGoodMen:Movie {title:"A Few Good Men", released:1992, tagline:"In the heart of the nation's capital, in a courthouse of the U.S. government, one man will stop at nothing to keep his honor, and one will stop at nothing to find the truth."})
CREATE (TomC:Person {name:'Tom Cruise', born:1962})
CREATE (JackN:Person {name:'Jack Nicholson', born:1937})
CREATE (DemiM:Person {name:'Demi Moore', born:1962})
CREATE (KevinB:Person {name:'Kevin Bacon', born:1958})
CREATE (KieferS:Person {name:'Kiefer Sutherland', born:1966})
CREATE (NoahW:Person {name:'Noah Wyle', born:1971})
CREATE (CubaG:Person {name:'Cuba Gooding Jr.', born:1968})
CREATE (KevinP:Person {name:'Kevin Pollak', born:1957})
CREATE (JTW:Person {name:'J.T. Walsh', born:1943})
CREATE (JamesM:Person {name:'James Marshall', born:1967})
CREATE (ChristopherG:Person {name:'Christopher Guest', born:1948})
CREATE (RobR:Person {name:'Rob Reiner', born:1947})
CREATE (AaronS:Person {name:'Aaron Sorkin', born:1961})
CREATE
(TomC)-[:ACTED_IN {roles:['Lt. Daniel Kaffee']}]->(AFewGoodMen),
(JackN)-[:ACTED_IN {roles:['Col. Nathan R. Jessup']}]->(AFewGoodMen),
(DemiM)-[:ACTED_IN {roles:['Lt. Cdr. JoAnne Galloway']}]->(AFewGoodMen),
(KevinB)-[:ACTED_IN {roles:['Capt. Jack Ross']}]->(AFewGoodMen),
(KieferS)-[:ACTED_IN {roles:['Lt. Jonathan Kendrick']}]->(AFewGoodMen),
(NoahW)-[:ACTED_IN {roles:['Cpl. Jeffrey Barnes']}]->(AFewGoodMen),
(CubaG)-[:ACTED_IN {roles:['Cpl. Carl Hammaker']}]->(AFewGoodMen),
(KevinP)-[:ACTED_IN {roles:['Lt. Sam Weinberg']}]->(AFewGoodMen),
(JTW)-[:ACTED_IN {roles:['Lt. Col. Matthew Andrew Markinson']}]->(AFewGoodMen),
(JamesM)-[:ACTED_IN {roles:['Pfc. Louden Downey']}]->(AFewGoodMen),
(ChristopherG)-[:ACTED_IN {roles:['Dr. Stone']}]->(AFewGoodMen),
(AaronS)-[:ACTED_IN {roles:['Man in Bar']}]->(AFewGoodMen),
(RobR)-[:DIRECTED]->(AFewGoodMen),
(AaronS)-[:WROTE]->(AFewGoodMen)

CREATE (TopGun:Movie {title:"Top Gun", released:1986, tagline:'I feel the need, the need for speed.'})
CREATE (KellyM:Person {name:'Kelly McGillis', born:1957})
CREATE (ValK:Person {name:'Val Kilmer', born:1959})
CREATE (AnthonyE:Person {name:'Anthony Edwards', born:1962})
CREATE (TomS:Person {name:'Tom Skerritt', born:1933})
CREATE (MegR:Person {name:'Meg Ryan', born:1961})
CREATE (TonyS:Person {name:'Tony Scott', born:1944})
CREATE (JimC:Person {name:'Jim Cash', born:1941})
CREATE
(TomC)-[:ACTED_IN {roles:['Maverick']}]->(TopGun),
(KellyM)-[:ACTED_IN {roles:['Charlie']}]->(TopGun),
(ValK)-[:ACTED_IN {roles:['Iceman']}]->(TopGun),
(AnthonyE)-[:ACTED_IN {roles:['Goose']}]->(TopGun),
(TomS)-[:ACTED_IN {roles:['Viper']}]->(TopGun),
(MegR)-[:ACTED_IN {roles:['Carole']}]->(TopGun),
(TonyS)-[:DIRECTED]->(TopGun),
(JimC)-[:WROTE]->(TopGun)

CREATE (JerryMaguire:Movie {title:'Jerry Maguire', released:2000, tagline:'The rest of his life begins now.'})
CREATE (ReneeZ:Person {name:'Renee Zellweger', born:1969})
CREATE (KellyP:Person {name:'Kelly Preston', born:1962})
CREATE (JerryO:Person {name:"Jerry O'Connell", born:1974})
CREATE (JayM:Person {name:'Jay Mohr', born:1970})
CREATE (BonnieH:Person {name:'Bonnie Hunt', born:1961})
CREATE (ReginaK:Person {name:'Regina King', born:1971})
CREATE (JonathanL:Person {name:'Jonathan Lipnicki', born:1996})
CREATE (CameronC:Person {name:'Cameron Crowe', born:1957})
CREATE
(TomC)-[:ACTED_IN {roles:['Jerry Maguire']}]->(JerryMaguire),
(CubaG)-[:ACTED_IN {roles:['Rod Tidwell']}]->(JerryMaguire),
(ReneeZ)-[:ACTED_IN {roles:['Dorothy Boyd']}]->(JerryMaguire),
(KellyP)-[:ACTED_IN {roles:['Avery Bishop']}]->(JerryMaguire),
(JerryO)-[:ACTED_IN {roles:['Frank Cushman']}]->(JerryMaguire),
(JayM)-[:ACTED_IN {roles:['Bob Sugar']}]->(JerryMaguire),
(BonnieH)-[:ACTED_IN {roles:['Laurel Boyd']}]->(JerryMaguire),
(ReginaK)-[:ACTED_IN {roles:['Marcee Tidwell']}]->(JerryMaguire),
(JonathanL)-[:ACTED_IN {roles:['Ray Boyd']}]->(JerryMaguire),
(CameronC)-[:DIRECTED]->(JerryMaguire),
(CameronC)-[:PRODUCED]->(JerryMaguire),
(CameronC)-[:WROTE]->(JerryMaguire)

CREATE (StandByMe:Movie {title:"Stand By Me", released:1986, tagline:"For some, it's the last real taste of innocence, and the first real taste of life. But for everyone, it's the time that memories are made of."})
CREATE (RiverP:Person {name:'River Phoenix', born:1970})
CREATE (CoreyF:Person {name:'Corey Feldman', born:1971})
CREATE (WilW:Person {name:'Wil Wheaton', born:1972})
CREATE (JohnC:Person {name:'John Cusack', born:1966})
CREATE (MarshallB:Person {name:'Marshall Bell', born:1942})
CREATE
(WilW)-[:ACTED_IN {roles:['Gordie Lachance']}]->(StandByMe),
(RiverP)-[:ACTED_IN {roles:['Chris Chambers']}]->(StandByMe),
(JerryO)-[:ACTED_IN {roles:['Vern Tessio']}]->(StandByMe),
(CoreyF)-[:ACTED_IN {roles:['Teddy Duchamp']}]->(StandByMe),
(JohnC)-[:ACTED_IN {roles:['Denny Lachance']}]->(StandByMe),
(KieferS)-[:ACTED_IN {roles:['Ace Merrill']}]->(StandByMe),
(MarshallB)-[:ACTED_IN {roles:['Mr. Lachance']}]->(StandByMe),
(RobR)-[:DIRECTED]->(StandByMe)

CREATE (AsGoodAsItGets:Movie {title:'As Good as It Gets', released:1997, tagline:'A comedy from the heart that goes for the throat.'})
CREATE (HelenH:Person {name:'Helen Hunt', born:1963})
CREATE (GregK:Person {name:'Greg Kinnear', born:1963})
CREATE (JamesB:Person {name:'James L. Brooks', born:1940})
CREATE
(JackN)-[:ACTED_IN {roles:['Melvin Udall']}]->(AsGoodAsItGets),
(HelenH)-[:ACTED_IN {roles:['Carol Connelly']}]->(AsGoodAsItGets),
(GregK)-[:ACTED_IN {roles:['Simon Bishop']}]->(AsGoodAsItGets),
(CubaG)-[:ACTED_IN {roles:['Frank Sachs']}]->(AsGoodAsItGets),
(JamesB)-[:DIRECTED]->(AsGoodAsItGets)

CREATE (WhatDreamsMayCome:Movie {title:'What Dreams May Come', released:1998, tagline:'After life there is more. The end is just the beginning.'})
CREATE (AnnabellaS:Person {name:'Annabella Sciorra', born:1960})
CREATE (MaxS:Person {name:'Max von Sydow', born:1929})
CREATE (WernerH:Person {name:'Werner Herzog', born:1942})
CREATE (Robin:Person {name:'Robin Williams', born:1951})
CREATE (VincentW:Person {name:'Vincent Ward', born:1956})
CREATE
(Robin)-[:ACTED_IN {roles:['Chris Nielsen']}]->(WhatDreamsMayCome),
(CubaG)-[:ACTED_IN {roles:['Albert Lewis']}]->(WhatDreamsMayCome),
(AnnabellaS)-[:ACTED_IN {roles:['Annie Collins-Nielsen']}]->(WhatDreamsMayCome),
(MaxS)-[:ACTED_IN {roles:['The Tracker']}]->(WhatDreamsMayCome),
(WernerH)-[:ACTED_IN {roles:['The Face']}]->(WhatDreamsMayCome),
(VincentW)-[:DIRECTED]->(WhatDreamsMayCome)

CREATE (SnowFallingonCedars:Movie {title:'Snow Falling on Cedars', released:1999, tagline:'First loves last. Forever.'})
CREATE (EthanH:Person {name:'Ethan Hawke', born:1970})
CREATE (RickY:Person {name:'Rick Yune', born:1971})
CREATE (JamesC:Person {name:'James Cromwell', born:1940})
CREATE (ScottH:Person {name:'Scott Hicks', born:1953})
CREATE
(EthanH)-[:ACTED_IN {roles:['Ishmael Chambers']}]->(SnowFallingonCedars),
(RickY)-[:ACTED_IN {roles:['Kazuo Miyamoto']}]->(SnowFallingonCedars),
(MaxS)-[:ACTED_IN {roles:['Nels Gudmundsson']}]->(SnowFallingonCedars),
(JamesC)-[:ACTED_IN {roles:['Judge Fielding']}]->(SnowFallingonCedars),
(ScottH)-[:DIRECTED]->(SnowFallingonCedars)

CREATE (YouveGotMail:Movie {title:"You've Got Mail", released:1998, tagline:'At odds in life... in love on-line.'})
CREATE (ParkerP:Person {name:'Parker Posey', born:1968})
CREATE (DaveC:Person {name:'Dave Chappelle', born:1973})
CREATE (SteveZ:Person {name:'Steve Zahn', born:1967})
CREATE (TomH:Person {name:'Tom Hanks', born:1956})
CREATE (NoraE:Person {name:'Nora Ephron', born:1941})
CREATE
(TomH)-[:ACTED_IN {roles:['Joe Fox']}]->(YouveGotMail),
(MegR)-[:ACTED_IN {roles:['Kathleen Kelly']}]->(YouveGotMail),
(GregK)-[:ACTED_IN {roles:['Frank Navasky']}]->(YouveGotMail),
(ParkerP)-[:ACTED_IN {roles:['Patricia Eden']}]->(YouveGotMail),
(DaveC)-[:ACTED_IN {roles:['Kevin Jackson']}]->(YouveGotMail),
(SteveZ)-[:ACTED_IN {roles:['George Pappas']}]->(YouveGotMail),
(NoraE)-[:DIRECTED]->(YouveGotMail)

CREATE (SleeplessInSeattle:Movie {title:'Sleepless in Seattle', released:1993, tagline:'What if someone you never met, someone you never saw, someone you never knew was the only someone for you?'})
CREATE (RitaW:Person {name:'Rita Wilson', born:1956})
CREATE (BillPull:Person {name:'Bill Pullman', born:1953})
CREATE (VictorG:Person {name:'Victor Garber', born:1949})
CREATE (RosieO:Person {name:"Rosie O'Donnell", born:1962})
CREATE
(TomH)-[:ACTED_IN {roles:['Sam Baldwin']}]->(SleeplessInSeattle),
(MegR)-[:ACTED_IN {roles:['Annie Reed']}]->(SleeplessInSeattle),
(RitaW)-[:ACTED_IN {roles:['Suzy']}]->(SleeplessInSeattle),
(BillPull)-[:ACTED_IN {roles:['Walter']}]->(SleeplessInSeattle),
(VictorG)-[:ACTED_IN {roles:['Greg']}]->(SleeplessInSeattle),
(RosieO)-[:ACTED_IN {roles:['Becky']}]->(SleeplessInSeattle),
(NoraE)-[:DIRECTED]->(SleeplessInSeattle)

CREATE (JoeVersustheVolcano:Movie {title:'Joe Versus the Volcano', released:1990, tagline:'A story of love, lava and burning desire.'})
CREATE (JohnS:Person {name:'John Patrick Stanley', born:1950})
CREATE (Nathan:Person {name:'Nathan Lane', born:1956})
CREATE
(TomH)-[:ACTED_IN {roles:['Joe Banks']}]->(JoeVersustheVolcano),
(MegR)-[:ACTED_IN {roles:['DeDe', 'Angelica Graynamore', 'Patricia Graynamore']}]->(JoeVersustheVolcano),
(Nathan)-[:ACTED_IN {roles:['Baw']}]->(JoeVersustheVolcano),
(JohnS)-[:DIRECTED]->(JoeVersustheVolcano)

CREATE (WhenHarryMetSally:Movie {title:'When Harry Met Sally', released:1998, tagline:'Can two friends sleep together and still love each other in the morning?'})
CREATE (BillyC:Person {name:'Billy Crystal', born:1948})
CREATE (CarrieF:Person {name:'Carrie Fisher', born:1956})
CREATE (BrunoK:Person {name:'Bruno Kirby', born:1949})
CREATE
(BillyC)-[:ACTED_IN {roles:['Harry Burns']}]->(WhenHarryMetSally),
(MegR)-[:ACTED_IN {roles:['Sally Albright']}]->(WhenHarryMetSally),
(CarrieF)-[:ACTED_IN {roles:['Marie']}]->(WhenHarryMetSally),
(BrunoK)-[:ACTED_IN {roles:['Jess']}]->(WhenHarryMetSally),
(RobR)-[:DIRECTED]->(WhenHarryMetSally),
(RobR)-[:PRODUCED]->(WhenHarryMetSally),
(NoraE)-[:PRODUCED]->(WhenHarryMetSally),
(NoraE)-[:WROTE]->(WhenHarryMetSally)

CREATE (ThatThingYouDo:Movie {title:'That Thing You Do', released:1996, tagline:'In every life there comes a time when that thing you dream becomes that thing you do'})
CREATE (LivT:Person {name:'Liv Tyler', born:1977})
CREATE
(TomH)-[:ACTED_IN {roles:['Mr. White']}]->(ThatThingYouDo),
(LivT)-[:ACTED_IN {roles:['Faye Dolan']}]->(ThatThingYouDo),
(Charlize)-[:ACTED_IN {roles:['Tina']}]->(ThatThingYouDo),
(TomH)-[:DIRECTED]->(ThatThingYouDo)

CREATE (TheReplacements:Movie {title:'The Replacements', released:2000, tagline:'Pain heals, Chicks dig scars... Glory lasts forever'})
CREATE (Brooke:Person {name:'Brooke Langton', born:1970})
CREATE (Gene:Person {name:'Gene Hackman', born:1930})
CREATE (Orlando:Person {name:'Orlando Jones', born:1968})
CREATE (Howard:Person {name:'Howard Deutch', born:1950})
CREATE
(Keanu)-[:ACTED_IN {roles:['Shane Falco']}]->(TheReplacements),
(Brooke)-[:ACTED_IN {roles:['Annabelle Farrell']}]->(TheReplacements),
(Gene)-[:ACTED_IN {roles:['Jimmy McGinty']}]->(TheReplacements),
(Orlando)-[:ACTED_IN {roles:['Clifford Franklin']}]->(TheReplacements),
(Howard)-[:DIRECTED]->(TheReplacements)

CREATE (RescueDawn:Movie {title:'RescueDawn', released:2006, tagline:"Based on the extraordinary true story of one man's fight for freedom"})
CREATE (ChristianB:Person {name:'Christian Bale', born:1974})
CREATE (ZachG:Person {name:'Zach Grenier', born:1954})
CREATE
(MarshallB)-[:ACTED_IN {roles:['Admiral']}]->(RescueDawn),
(ChristianB)-[:ACTED_IN {roles:['Dieter Dengler']}]->(RescueDawn),
(ZachG)-[:ACTED_IN {roles:['Squad Leader']}]->(RescueDawn),
(SteveZ)-[:ACTED_IN {roles:['Duane']}]->(RescueDawn),
(WernerH)-[:DIRECTED]->(RescueDawn)

CREATE (TheBirdcage:Movie {title:'The Birdcage', released:1996, tagline:'Come as you are'})
CREATE (MikeN:Person {name:'Mike Nichols', born:1931})
CREATE
(Robin)-[:ACTED_IN {roles:['Armand Goldman']}]->(TheBirdcage),
(Nathan)-[:ACTED_IN {roles:['Albert Goldman']}]->(TheBirdcage),
(Gene)-[:ACTED_IN {roles:['Sen. Kevin Keeley']}]->(TheBirdcage),
(MikeN)-[:DIRECTED]->(TheBirdcage)

CREATE (Unforgiven:Movie {title:'Unforgiven', released:1992, tagline:"It's a hell of a thing, killing a man"})
CREATE (RichardH:Person {name:'Richard Harris', born:1930})
CREATE (ClintE:Person {name:'Clint Eastwood', born:1930})
CREATE
(RichardH)-[:ACTED_IN {roles:['English Bob']}]->(Unforgiven),
(ClintE)-[:ACTED_IN {roles:['Bill Munny']}]->(Unforgiven),
(Gene)-[:ACTED_IN {roles:['Little Bill Daggett']}]->(Unforgiven),
(ClintE)-[:DIRECTED]->(Unforgiven)

CREATE (JohnnyMnemonic:Movie {title:'Johnny Mnemonic', released:1995, tagline:'The hottest data on earth. In the coolest head in town'})
CREATE (Takeshi:Person {name:'Takeshi Kitano', born:1947})
CREATE (Dina:Person {name:'Dina Meyer', born:1968})
CREATE (IceT:Person {name:'Ice-T', born:1958})
CREATE (RobertL:Person {name:'Robert Longo', born:1953})
CREATE
(Keanu)-[:ACTED_IN {roles:['Johnny Mnemonic']}]->(JohnnyMnemonic),
(Takeshi)-[:ACTED_IN {roles:['Takahashi']}]->(JohnnyMnemonic),
(Dina)-[:ACTED_IN {roles:['Jane']}]->(JohnnyMnemonic),
(IceT)-[:ACTED_IN {roles:['J-Bone']}]->(JohnnyMnemonic),
(RobertL)-[:DIRECTED]->(JohnnyMnemonic)

CREATE (CloudAtlas:Movie {title:'Cloud Atlas', released:2012, tagline:'Everything is connected'})
CREATE (HalleB:Person {name:'Halle Berry', born:1966})
CREATE (JimB:Person {name:'Jim Broadbent', born:1949})
CREATE (TomT:Person {name:'Tom Tykwer', born:1965})
CREATE (DavidMitchell:Person {name:'David Mitchell', born:1969})
CREATE (StefanArndt:Person {name:'Stefan Arndt', born:1961})
CREATE
(TomH)-[:ACTED_IN {roles:['Zachry', 'Dr. Henry Goose', 'Isaac Sachs', 'Dermot Hoggins']}]->(CloudAtlas),
(Hugo)-[:ACTED_IN {roles:['Bill Smoke', 'Haskell Moore', 'Tadeusz Kesselring', 'Nurse Noakes', 'Boardman Mephi', 'Old Georgie']}]->(CloudAtlas),
(HalleB)-[:ACTED_IN {roles:['Luisa Rey', 'Jocasta Ayrs', 'Ovid', 'Meronym']}]->(CloudAtlas),
(JimB)-[:ACTED_IN {roles:['Vyvyan Ayrs', 'Captain Molyneux', 'Timothy Cavendish']}]->(CloudAtlas),
(TomT)-[:DIRECTED]->(CloudAtlas),
(LillyW)-[:DIRECTED]->(CloudAtlas),
(LanaW)-[:DIRECTED]->(CloudAtlas),
(DavidMitchell)-[:WROTE]->(CloudAtlas),
(StefanArndt)-[:PRODUCED]->(CloudAtlas)

CREATE (TheDaVinciCode:Movie {title:'The Da Vinci Code', released:2006, tagline:'Break The Codes'})
CREATE (IanM:Person {name:'Ian McKellen', born:1939})
CREATE (AudreyT:Person {name:'Audrey Tautou', born:1976})
CREATE (PaulB:Person {name:'Paul Bettany', born:1971})
CREATE (RonH:Person {name:'Ron Howard', born:1954})
CREATE
(TomH)-[:ACTED_IN {roles:['Dr. Robert Langdon']}]->(TheDaVinciCode),
(IanM)-[:ACTED_IN {roles:['Sir Leight Teabing']}]->(TheDaVinciCode),
(AudreyT)-[:ACTED_IN {roles:['Sophie Neveu']}]->(TheDaVinciCode),
(PaulB)-[:ACTED_IN {roles:['Silas']}]->(TheDaVinciCode),
(RonH)-[:DIRECTED]->(TheDaVinciCode)

CREATE (VforVendetta:Movie {title:'V for Vendetta', released:2006, tagline:'Freedom! Forever!'})
CREATE (NatalieP:Person {name:'Natalie Portman', born:1981})
CREATE (StephenR:Person {name:'Stephen Rea', born:1946})
CREATE (JohnH:Person {name:'John Hurt', born:1940})
CREATE (BenM:Person {name: 'Ben Miles', born:1967})
CREATE
(Hugo)-[:ACTED_IN {roles:['V']}]->(VforVendetta),
(NatalieP)-[:ACTED_IN {roles:['Evey Hammond']}]->(VforVendetta),
(StephenR)-[:ACTED_IN {roles:['Eric Finch']}]->(VforVendetta),
(JohnH)-[:ACTED_IN {roles:['High Chancellor Adam Sutler']}]->(VforVendetta),
(BenM)-[:ACTED_IN {roles:['Dascomb']}]->(VforVendetta),
(JamesM)-[:DIRECTED]->(VforVendetta),
(LillyW)-[:PRODUCED]->(VforVendetta),
(LanaW)-[:PRODUCED]->(VforVendetta),
(JoelS)-[:PRODUCED]->(VforVendetta),
(LillyW)-[:WROTE]->(VforVendetta),
(LanaW)-[:WROTE]->(VforVendetta)

CREATE (SpeedRacer:Movie {title:'Speed Racer', released:2008, tagline:'Speed has no limits'})
CREATE (EmileH:Person {name:'Emile Hirsch', born:1985})
CREATE (JohnG:Person {name:'John Goodman', born:1960})
CREATE (SusanS:Person {name:'Susan Sarandon', born:1946})
CREATE (MatthewF:Person {name:'Matthew Fox', born:1966})
CREATE (ChristinaR:Person {name:'Christina Ricci', born:1980})
CREATE (Rain:Person {name:'Rain', born:1982})
CREATE
(EmileH)-[:ACTED_IN {roles:['Speed Racer']}]->(SpeedRacer),
(JohnG)-[:ACTED_IN {roles:['Pops']}]->(SpeedRacer),
(SusanS)-[:ACTED_IN {roles:['Mom']}]->(SpeedRacer),
(MatthewF)-[:ACTED_IN {roles:['Racer X']}]->(SpeedRacer),
(ChristinaR)-[:ACTED_IN {roles:['Trixie']}]->(SpeedRacer),
(Rain)-[:ACTED_IN {roles:['Taejo Togokahn']}]->(SpeedRacer),
(BenM)-[:ACTED_IN {roles:['Cass Jones']}]->(SpeedRacer),
(LillyW)-[:DIRECTED]->(SpeedRacer),
(LanaW)-[:DIRECTED]->(SpeedRacer),
(LillyW)-[:WROTE]->(SpeedRacer),
(LanaW)-[:WROTE]->(SpeedRacer),
(JoelS)-[:PRODUCED]->(SpeedRacer)

CREATE (NinjaAssassin:Movie {title:'Ninja Assassin', released:2009, tagline:'Prepare to enter a secret world of assassins'})
CREATE (NaomieH:Person {name:'Naomie Harris'})
CREATE
(Rain)-[:ACTED_IN {roles:['Raizo']}]->(NinjaAssassin),
(NaomieH)-[:ACTED_IN {roles:['Mika Coretti']}]->(NinjaAssassin),
(RickY)-[:ACTED_IN {roles:['Takeshi']}]->(NinjaAssassin),
(BenM)-[:ACTED_IN {roles:['Ryan Maslow']}]->(NinjaAssassin),
(JamesM)-[:DIRECTED]->(NinjaAssassin),
(LillyW)-[:PRODUCED]->(NinjaAssassin),
(LanaW)-[:PRODUCED]->(NinjaAssassin),
(JoelS)-[:PRODUCED]->(NinjaAssassin)

CREATE (TheGreenMile:Movie {title:'The Green Mile', released:1999, tagline:"Walk a mile you'll never forget."})
CREATE (MichaelD:Person {name:'Michael Clarke Duncan', born:1957})
CREATE (DavidM:Person {name:'David Morse', born:1953})
CREATE (SamR:Person {name:'Sam Rockwell', born:1968})
CREATE (GaryS:Person {name:'Gary Sinise', born:1955})
CREATE (PatriciaC:Person {name:'Patricia Clarkson', born:1959})
CREATE (FrankD:Person {name:'Frank Darabont', born:1959})
CREATE
(TomH)-[:ACTED_IN {roles:['Paul Edgecomb']}]->(TheGreenMile),
(MichaelD)-[:ACTED_IN {roles:['John Coffey']}]->(TheGreenMile),
(DavidM)-[:ACTED_IN {roles:['Brutus "Brutal" Howell']}]->(TheGreenMile),
(BonnieH)-[:ACTED_IN {roles:['Jan Edgecomb']}]->(TheGreenMile),
(JamesC)-[:ACTED_IN {roles:['Warden Hal Moores']}]->(TheGreenMile),
(SamR)-[:ACTED_IN {roles:['"Wild Bill" Wharton']}]->(TheGreenMile),
(GaryS)-[:ACTED_IN {roles:['Burt Hammersmith']}]->(TheGreenMile),
(PatriciaC)-[:ACTED_IN {roles:['Melinda Moores']}]->(TheGreenMile),
(FrankD)-[:DIRECTED]->(TheGreenMile)

CREATE (FrostNixon:Movie {title:'Frost/Nixon', released:2008, tagline:'400 million people were waiting for the truth.'})
CREATE (FrankL:Person {name:'Frank Langella', born:1938})
CREATE (MichaelS:Person {name:'Michael Sheen', born:1969})
CREATE (OliverP:Person {name:'Oliver Platt', born:1960})
CREATE
(FrankL)-[:ACTED_IN {roles:['Richard Nixon']}]->(FrostNixon),
(MichaelS)-[:ACTED_IN {roles:['David Frost']}]->(FrostNixon),
(KevinB)-[:ACTED_IN {roles:['Jack Brennan']}]->(FrostNixon),
(OliverP)-[:ACTED_IN {roles:['Bob Zelnick']}]->(FrostNixon),
(SamR)-[:ACTED_IN {roles:['James Reston, Jr.']}]->(FrostNixon),
(RonH)-[:DIRECTED]->(FrostNixon)

CREATE (Hoffa:Movie {title:'Hoffa', released:1992, tagline:"He didn't want law. He wanted justice."})
CREATE (DannyD:Person {name:'Danny DeVito', born:1944})
CREATE (JohnR:Person {name:'John C. Reilly', born:1965})
CREATE
(JackN)-[:ACTED_IN {roles:['Hoffa']}]->(Hoffa),
(DannyD)-[:ACTED_IN {roles:['Robert "Bobby" Ciaro']}]->(Hoffa),
(JTW)-[:ACTED_IN {roles:['Frank Fitzsimmons']}]->(Hoffa),
(JohnR)-[:ACTED_IN {roles:['Peter "Pete" Connelly']}]->(Hoffa),
(DannyD)-[:DIRECTED]->(Hoffa)

CREATE (Apollo13:Movie {title:'Apollo 13', released:1995, tagline:'Houston, we have a problem.'})
CREATE (EdH:Person {name:'Ed Harris', born:1950})
CREATE (BillPax:Person {name:'Bill Paxton', born:1955})
CREATE
(TomH)-[:ACTED_IN {roles:['Jim Lovell']}]->(Apollo13),
(KevinB)-[:ACTED_IN {roles:['Jack Swigert']}]->(Apollo13),
(EdH)-[:ACTED_IN {roles:['Gene Kranz']}]->(Apollo13),
(BillPax)-[:ACTED_IN {roles:['Fred Haise']}]->(Apollo13),
(GaryS)-[:ACTED_IN {roles:['Ken Mattingly']}]->(Apollo13),
(RonH)-[:DIRECTED]->(Apollo13)

CREATE (Twister:Movie {title:'Twister', released:1996, tagline:"Don't Breathe. Don't Look Back."})
CREATE (PhilipH:Person {name:'Philip Seymour Hoffman', born:1967})
CREATE (JanB:Person {name:'Jan de Bont', born:1943})
CREATE
(BillPax)-[:ACTED_IN {roles:['Bill Harding']}]->(Twister),
(HelenH)-[:ACTED_IN {roles:['Dr. Jo Harding']}]->(Twister),
(ZachG)-[:ACTED_IN {roles:['Eddie']}]->(Twister),
(PhilipH)-[:ACTED_IN {roles:['Dustin "Dusty" Davis']}]->(Twister),
(JanB)-[:DIRECTED]->(Twister)

CREATE (CastAway:Movie {title:'Cast Away', released:2000, tagline:'At the edge of the world, his journey begins.'})
CREATE (RobertZ:Person {name:'Robert Zemeckis', born:1951})
CREATE
(TomH)-[:ACTED_IN {roles:['Chuck Noland']}]->(CastAway),
(HelenH)-[:ACTED_IN {roles:['Kelly Frears']}]->(CastAway),
(RobertZ)-[:DIRECTED]->(CastAway)

CREATE (OneFlewOvertheCuckoosNest:Movie {title:"One Flew Over the Cuckoo's Nest", released:1975, tagline:"If he's crazy, what does that make you?"})
CREATE (MilosF:Person {name:'Milos Forman', born:1932})
CREATE
(JackN)-[:ACTED_IN {roles:['Randle McMurphy']}]->(OneFlewOvertheCuckoosNest),
(DannyD)-[:ACTED_IN {roles:['Martini']}]->(OneFlewOvertheCuckoosNest),
(MilosF)-[:DIRECTED]->(OneFlewOvertheCuckoosNest)

CREATE (SomethingsGottaGive:Movie {title:"Something's Gotta Give", released:2003})
CREATE (DianeK:Person {name:'Diane Keaton', born:1946})
CREATE (NancyM:Person {name:'Nancy Meyers', born:1949})
CREATE
(JackN)-[:ACTED_IN {roles:['Harry Sanborn']}]->(SomethingsGottaGive),
(DianeK)-[:ACTED_IN {roles:['Erica Barry']}]->(SomethingsGottaGive),
(Keanu)-[:ACTED_IN {roles:['Julian Mercer']}]->(SomethingsGottaGive),
(NancyM)-[:DIRECTED]->(SomethingsGottaGive),
(NancyM)-[:PRODUCED]->(SomethingsGottaGive),
(NancyM)-[:WROTE]->(SomethingsGottaGive)

CREATE (BicentennialMan:Movie {title:'Bicentennial Man', released:1999, tagline:"One robot's 200 year journey to become an ordinary man."})
CREATE (ChrisC:Person {name:'Chris Columbus', born:1958})
CREATE
(Robin)-[:ACTED_IN {roles:['Andrew Marin']}]->(BicentennialMan),
(OliverP)-[:ACTED_IN {roles:['Rupert Burns']}]->(BicentennialMan),
(ChrisC)-[:DIRECTED]->(BicentennialMan)

CREATE (CharlieWilsonsWar:Movie {title:"Charlie Wilson's War", released:2007, tagline:"A stiff drink. A little mascara. A lot of nerve. Who said they couldn't bring down the Soviet empire."})
CREATE (JuliaR:Person {name:'Julia Roberts', born:1967})
CREATE
(TomH)-[:ACTED_IN {roles:['Rep. Charlie Wilson']}]->(CharlieWilsonsWar),
(JuliaR)-[:ACTED_IN {roles:['Joanne Herring']}]->(CharlieWilsonsWar),
(PhilipH)-[:ACTED_IN {roles:['Gust Avrakotos']}]->(CharlieWilsonsWar),
(MikeN)-[:DIRECTED]->(CharlieWilsonsWar)

CREATE (ThePolarExpress:Movie {title:'The Polar Express', released:2004, tagline:'This Holiday Season... Believe'})
CREATE
(TomH)-[:ACTED_IN {roles:['Hero Boy', 'Father', 'Conductor', 'Hobo', 'Scrooge', 'Santa Claus']}]->(ThePolarExpress),
(RobertZ)-[:DIRECTED]->(ThePolarExpress)

CREATE (ALeagueofTheirOwn:Movie {title:'A League of Their Own', released:1992, tagline:'Once in a lifetime you get a chance to do something different.'})
CREATE (Madonna:Person {name:'Madonna', born:1954})
CREATE (GeenaD:Person {name:'Geena Davis', born:1956})
CREATE (LoriP:Person {name:'Lori Petty', born:1963})
CREATE (PennyM:Person {name:'Penny Marshall', born:1943})
CREATE
(TomH)-[:ACTED_IN {roles:['Jimmy Dugan']}]->(ALeagueofTheirOwn),
(GeenaD)-[:ACTED_IN {roles:['Dottie Hinson']}]->(ALeagueofTheirOwn),
(LoriP)-[:ACTED_IN {roles:['Kit Keller']}]->(ALeagueofTheirOwn),
(RosieO)-[:ACTED_IN {roles:['Doris Murphy']}]->(ALeagueofTheirOwn),
(Madonna)-[:ACTED_IN {roles:['"All the Way" Mae Mordabito']}]->(ALeagueofTheirOwn),
(BillPax)-[:ACTED_IN {roles:['Bob Hinson']}]->(ALeagueofTheirOwn),
(PennyM)-[:DIRECTED]->(ALeagueofTheirOwn)

CREATE (PaulBlythe:Person {name:'Paul Blythe'})
CREATE (AngelaScope:Person {name:'Angela Scope'})
CREATE (JessicaThompson:Person {name:'Jessica Thompson'})
CREATE (JamesThompson:Person {name:'James Thompson'})

CREATE
(JamesThompson)-[:FOLLOWS]->(JessicaThompson),
(AngelaScope)-[:FOLLOWS]->(JessicaThompson),
(PaulBlythe)-[:FOLLOWS]->(AngelaScope)

CREATE
(JessicaThompson)-[:REVIEWED {summary:'An amazing journey', rating:95}]->(CloudAtlas),
(JessicaThompson)-[:REVIEWED {summary:'Silly, but fun', rating:65}]->(TheReplacements),
(JamesThompson)-[:REVIEWED {summary:'The coolest football movie ever', rating:100}]->(TheReplacements),
(AngelaScope)-[:REVIEWED {summary:'Pretty funny at times', rating:62}]->(TheReplacements),
(JessicaThompson)-[:REVIEWED {summary:'Dark, but compelling', rating:85}]->(Unforgiven),
(JessicaThompson)-[:REVIEWED {summary:"Slapstick redeemed only by the Robin Williams and Gene Hackman's stellar performances", rating:45}]->(TheBirdcage),
(JessicaThompson)-[:REVIEWED {summary:'A solid romp', rating:68}]->(TheDaVinciCode),
(JamesThompson)-[:REVIEWED {summary:'Fun, but a little far fetched', rating:65}]->(TheDaVinciCode),
(JessicaThompson)-[:REVIEWED {summary:'You had me at Jerry', rating:92}]->(JerryMaguire)

WITH TomH as a
MATCH (a)-[:ACTED_IN]->(m)<-[:DIRECTED]-(d) RETURN a,m,d LIMIT 10;

:play movies

MATCH path = shortestPath(
    (:Person {name:$name})-[:ACTED_IN*..10]-(:Person {name:'Kevin Bacon'}) )
RETURN path, length(path);

:param name=>"Meg Ryan";

:play cypher-vs-sql

:clear

MATCH (cust:Customer)-[:PURCHASED]->(:Order)-[o:ORDERS]->(p:Product),
  (p)-[:PART_OF]->(c:Category {categoryName:"Produce"})
RETURN DISTINCT cust.contactName as CustomerName, SUM(o.quantity) AS TotalProductsPurchased;

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/order-details.csv" AS row
MATCH (p:Product), (o:Order)
WHERE p.productID = row.productID AND o.orderID = row.orderID
CREATE (o)-[details:ORDERS]->(p)
SET details = row,
details.quantity = toInteger(row.quantity);

CREATE INDEX ON :Order(orderID);

CREATE INDEX ON :Customer(customerID);

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/orders.csv" AS row
CREATE (n:Order)
SET n = row;

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/customers.csv" AS row
CREATE (n:Customer)
SET n = row;

MATCH (c:Category {categoryName:"Produce"})<--(:Product)<--(s:Supplier)
RETURN DISTINCT s.companyName as ProduceSuppliers;

MATCH (s:Supplier)-->(:Product)-->(c:Category)
RETURN s.companyName as Company, collect(distinct c.categoryName) as Categories;

MATCH (p:Product),(s:Supplier)
WHERE p.supplierID = s.supplierID
CREATE (s)-[:SUPPLIES]->(p);

MATCH (p:Product),(c:Category)
WHERE p.categoryID = c.categoryID
CREATE (p)-[:PART_OF]->(c);

CREATE INDEX ON :Supplier(supplierID);

CREATE INDEX ON :Category(categoryID);

CREATE INDEX ON :Product(productName);

CREATE INDEX ON :Product(productID);

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/suppliers.csv" AS row
CREATE (n:Supplier)
SET n = row;

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/categories.csv" AS row
CREATE (n:Category)
SET n = row;

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/products.csv" AS row
CREATE (n:Product)
SET n = row,
n.unitPrice = toFloat(row.unitPrice),
n.unitsInStock = toInteger(row.unitsInStock), n.unitsOnOrder = toInteger(row.unitsOnOrder),
n.reorderLevel = toInteger(row.reorderLevel), n.discontinued = (row.discontinued <> "0");

:play northwind

:play cypher-vs-sql

match (p:Person) where p.age is not null delete p;

:play cypher-vs-sql

:auto UNWIND range(1,1000000) as id
CALL { WITH id 
CREATE (p:Person {id:id, name:"Joe "+id, age:id%100})
} IN TRANSACTIONS OF 10000 ROWS
RETURN count(*);

// turn list into 10k rows
UNWIND range(1,10000) as id

CREATE (p:Person {id:id, name:"Joe "+id, age:id%100})

// aggregate people into age groups, collect per age-group
RETURN p.age, count(*) as ageCount, collect(p.name)[0..5] as ageGroup;

:guide cypher-vs-sql

MATCH (a:Person)-[:ACTED_IN]->(m:Movie)

WITH a, count(m) as movies WHERE movies > 2

MATCH (a)-[:DIRECTED]->(m)

RETURN a.name, collect(m.title) as movies, count(*) as count
ORDER BY count DESC LIMIT 5;

:use neo4j

MATCH (a:Person)-[:ACTED_IN]->(m:Movie)

WITH a, count(m) as movies WHERE movies > 2

MATCH (a)-[:DIRECTED]->(m)

RETURN a.name, collect(m.title) as movies, count(*) as count
ORDER BY count DESC LIMIT 5;

:play cypher-vs-sql

:guide intro

:guide aura/movies

:use system

WITH "https://data.neo4j.com/importing/ratings.csv" AS url
LOAD CSV WITH HEADERS FROM url AS row

MATCH (m:Movie {id:row.movieId})
MERGE (u:User {userId:row.userId})
ON CREATE SET u.name = row.name

MERGE (u)-[r:RATED]->(m)
SET r.rating = toFloat(row.rating)
SET r.timestamp = toInteger(row.timestamp);

WITH "https://data.neo4j.com/importing/ratings.csv" AS url
LOAD CSV WITH HEADERS FROM url AS row

MATCH (m:Movie {id:row.movieId})
MERGE (u:User {userId:row.userId})
ON CREATE SET u.name = row.name

MERGE (u)-[r:RATED]->(m)
SET r.rating = toFloat(row.rating)
SET r.timestamp = toInteger(row.timestamp;

load csv with headers from "https://data.neo4j.com/importing/ratings.csv" as row
return row limit 4;

:auto MATCH (o:Order) // imagine 100M
CALL { WITH o
    MATCH (o)-[r:ORDERS]->()
    WITH o, sum(r.count) as products, sum(toFloat(r.unitPrice)*r.quantity) as total
    SET o.count = products, o.total = total
} IN TRANSACTIONS OF 100000 ROWS

:auto MATCH (o:Order) // imagine 100M
CALL { WITH o
    MATCH (o)-[r:ORDERS]->()
    WITH o, sum(r.count) as products, sum(r.unitPrice*r.quantity) as total
    SET o.count = products, o.total = total
} IN TRANSACTIONS OF 100000 ROWS

MATCH (o:Order) // imagine 100M
CALL { WITH o
    MATCH (o)-[r:ORDERS]->()
    WITH o, sum(r.count) as products, sum(r.unitPrice*r.quantity) as total
    SET o.count = products, o.total = total
} IN TRANSACTIONS OF 100000 ROWS;

MATCH (o:Order) // imagine 100M
CALL { WITH o
    MATCH (o)-[r:ORDERS]->()
    WITH o, sum(r.count) as products, sum(r.unitPrice*r.quantity) as total
    SET o.count = count, o.total = total
} IN TRANSACTIONS OF 100000 ROWS;

match (o:Order) return o limit 5;

MATCH (cust:Customer)-[:PURCHASED]->(:Order)-[o:ORDERS]->(p:Product),
  (p)-[:PART_OF]->(c:Category {categoryName:"Produce"})
RETURN *;

MATCH (cust:Customer)-[:PURCHASED]->(:Order)-[o:ORDERS]->(p:Product),
  (p)-[:PART_OF]->(c:Category {categoryName:"Produce"})
RETURN DISTINCT cust.contactName as CustomerName, SUM(o.quantity) AS TotalProductsPurchased;

PROFILE MATCH (cust:Customer)-[:PURCHASED]->(:Order)-[o:ORDERS]->(p:Product),
  (p)-[:PART_OF]->(c:Category {categoryName:"Produce"})
RETURN DISTINCT cust.contactName as CustomerName, SUM(o.quantity) AS TotalProductsPurchased;

MATCH (cust:Customer)-[:PURCHASED]->(:Order)-[o:ORDERS]->(p:Product),
  (p)-[:PART_OF]->(c:Category {categoryName:"Produce"})
RETURN DISTINCT cust.contactName as CustomerName, SUM(o.quantity) AS TotalProductsPurchased;

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/order-details.csv" AS row
MATCH (p:Product), (o:Order)
WHERE p.productID = row.productID AND o.orderID = row.orderID
CREATE (o)-[details:ORDERS]->(p)
SET details = row,
details.quantity = toInteger(row.quantity);

MATCH (c:Customer),(o:Order)
WHERE c.customerID = o.customerID
CREATE (c)-[:PURCHASED]->(o);

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/orders.csv" AS row
CREATE (n:Order)
SET n = row;

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/customers.csv" AS row
CREATE (n:Customer)
SET n = row;

MATCH (c:Category {categoryName:"Produce"})<--(:Product)<--(s:Supplier)
RETURN DISTINCT s.companyName as ProduceSuppliers;

MATCH (s:Supplier)-->(:Product)-->(c:Category)
RETURN s.companyName as Company, collect(distinct c.categoryName) as Categories;

MATCH (p:Product),(s:Supplier)
WHERE p.supplierID = s.supplierID
CREATE (s)-[:SUPPLIES]->(p);

MATCH (p:Product),(c:Category)
WHERE p.categoryID = c.categoryID
CREATE (p)-[:PART_OF]->(c);

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/suppliers.csv" AS row
CREATE (n:Supplier)
SET n = row;

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/categories.csv" AS row
CREATE (n:Category)
SET n = row;

LOAD CSV WITH HEADERS FROM "http://data.neo4j.com/northwind/products.csv" AS row
CREATE (n:Product)
SET n = row,
n.unitPrice = toFloat(row.unitPrice),
n.unitsInStock = toInteger(row.unitsInStock), n.unitsOnOrder = toInteger(row.unitsOnOrder),
n.reorderLevel = toInteger(row.reorderLevel), n.discontinued = (row.discontinued <> "0");

:play northwind

:guide aura/movies

call dbms.components;

:guide aura/movies

:guide intro

call dbms.components();

:guide intro

:style reset

CREATE (TheMatrix:Movie {title:'The Matrix', released:1999, tagline:'Welcome to the Real World'})
CREATE (Keanu:Person {name:'Keanu Reeves', born:1964})
CREATE (Carrie:Person {name:'Carrie-Anne Moss', born:1967})
CREATE (Laurence:Person {name:'Laurence Fishburne', born:1961})
CREATE (Hugo:Person {name:'Hugo Weaving', born:1960})
CREATE (LillyW:Person {name:'Lilly Wachowski', born:1967})
CREATE (LanaW:Person {name:'Lana Wachowski', born:1965})
CREATE (JoelS:Person {name:'Joel Silver', born:1952})
CREATE
(Keanu)-[:ACTED_IN {roles:['Neo']}]->(TheMatrix),
(Carrie)-[:ACTED_IN {roles:['Trinity']}]->(TheMatrix),
(Laurence)-[:ACTED_IN {roles:['Morpheus']}]->(TheMatrix),
(Hugo)-[:ACTED_IN {roles:['Agent Smith']}]->(TheMatrix),
(LillyW)-[:DIRECTED]->(TheMatrix),
(LanaW)-[:DIRECTED]->(TheMatrix),
(JoelS)-[:PRODUCED]->(TheMatrix)

CREATE (Emil:Person {name:"Emil Eifrem", born:1978})
CREATE (Emil)-[:ACTED_IN {roles:["Emil"]}]->(TheMatrix)

CREATE (TheMatrixReloaded:Movie {title:'The Matrix Reloaded', released:2003, tagline:'Free your mind'})
CREATE
(Keanu)-[:ACTED_IN {roles:['Neo']}]->(TheMatrixReloaded),
(Carrie)-[:ACTED_IN {roles:['Trinity']}]->(TheMatrixReloaded),
(Laurence)-[:ACTED_IN {roles:['Morpheus']}]->(TheMatrixReloaded),
(Hugo)-[:ACTED_IN {roles:['Agent Smith']}]->(TheMatrixReloaded),
(LillyW)-[:DIRECTED]->(TheMatrixReloaded),
(LanaW)-[:DIRECTED]->(TheMatrixReloaded),
(JoelS)-[:PRODUCED]->(TheMatrixReloaded)

CREATE (TheMatrixRevolutions:Movie {title:'The Matrix Revolutions', released:2003, tagline:'Everything that has a beginning has an end'})
CREATE
(Keanu)-[:ACTED_IN {roles:['Neo']}]->(TheMatrixRevolutions),
(Carrie)-[:ACTED_IN {roles:['Trinity']}]->(TheMatrixRevolutions),
(Laurence)-[:ACTED_IN {roles:['Morpheus']}]->(TheMatrixRevolutions),
(Hugo)-[:ACTED_IN {roles:['Agent Smith']}]->(TheMatrixRevolutions),
(LillyW)-[:DIRECTED]->(TheMatrixRevolutions),
(LanaW)-[:DIRECTED]->(TheMatrixRevolutions),
(JoelS)-[:PRODUCED]->(TheMatrixRevolutions)

CREATE (TheDevilsAdvocate:Movie {title:"The Devil's Advocate", released:1997, tagline:'Evil has its winning ways'})
CREATE (Charlize:Person {name:'Charlize Theron', born:1975})
CREATE (Al:Person {name:'Al Pacino', born:1940})
CREATE (Taylor:Person {name:'Taylor Hackford', born:1944})
CREATE
(Keanu)-[:ACTED_IN {roles:['Kevin Lomax']}]->(TheDevilsAdvocate),
(Charlize)-[:ACTED_IN {roles:['Mary Ann Lomax']}]->(TheDevilsAdvocate),
(Al)-[:ACTED_IN {roles:['John Milton']}]->(TheDevilsAdvocate),
(Taylor)-[:DIRECTED]->(TheDevilsAdvocate)

CREATE (AFewGoodMen:Movie {title:"A Few Good Men", released:1992, tagline:"In the heart of the nation's capital, in a courthouse of the U.S. government, one man will stop at nothing to keep his honor, and one will stop at nothing to find the truth."})
CREATE (TomC:Person {name:'Tom Cruise', born:1962})
CREATE (JackN:Person {name:'Jack Nicholson', born:1937})
CREATE (DemiM:Person {name:'Demi Moore', born:1962})
CREATE (KevinB:Person {name:'Kevin Bacon', born:1958})
CREATE (KieferS:Person {name:'Kiefer Sutherland', born:1966})
CREATE (NoahW:Person {name:'Noah Wyle', born:1971})
CREATE (CubaG:Person {name:'Cuba Gooding Jr.', born:1968})
CREATE (KevinP:Person {name:'Kevin Pollak', born:1957})
CREATE (JTW:Person {name:'J.T. Walsh', born:1943})
CREATE (JamesM:Person {name:'James Marshall', born:1967})
CREATE (ChristopherG:Person {name:'Christopher Guest', born:1948})
CREATE (RobR:Person {name:'Rob Reiner', born:1947})
CREATE (AaronS:Person {name:'Aaron Sorkin', born:1961})
CREATE
(TomC)-[:ACTED_IN {roles:['Lt. Daniel Kaffee']}]->(AFewGoodMen),
(JackN)-[:ACTED_IN {roles:['Col. Nathan R. Jessup']}]->(AFewGoodMen),
(DemiM)-[:ACTED_IN {roles:['Lt. Cdr. JoAnne Galloway']}]->(AFewGoodMen),
(KevinB)-[:ACTED_IN {roles:['Capt. Jack Ross']}]->(AFewGoodMen),
(KieferS)-[:ACTED_IN {roles:['Lt. Jonathan Kendrick']}]->(AFewGoodMen),
(NoahW)-[:ACTED_IN {roles:['Cpl. Jeffrey Barnes']}]->(AFewGoodMen),
(CubaG)-[:ACTED_IN {roles:['Cpl. Carl Hammaker']}]->(AFewGoodMen),
(KevinP)-[:ACTED_IN {roles:['Lt. Sam Weinberg']}]->(AFewGoodMen),
(JTW)-[:ACTED_IN {roles:['Lt. Col. Matthew Andrew Markinson']}]->(AFewGoodMen),
(JamesM)-[:ACTED_IN {roles:['Pfc. Louden Downey']}]->(AFewGoodMen),
(ChristopherG)-[:ACTED_IN {roles:['Dr. Stone']}]->(AFewGoodMen),
(AaronS)-[:ACTED_IN {roles:['Man in Bar']}]->(AFewGoodMen),
(RobR)-[:DIRECTED]->(AFewGoodMen),
(AaronS)-[:WROTE]->(AFewGoodMen)

CREATE (TopGun:Movie {title:"Top Gun", released:1986, tagline:'I feel the need, the need for speed.'})
CREATE (KellyM:Person {name:'Kelly McGillis', born:1957})
CREATE (ValK:Person {name:'Val Kilmer', born:1959})
CREATE (AnthonyE:Person {name:'Anthony Edwards', born:1962})
CREATE (TomS:Person {name:'Tom Skerritt', born:1933})
CREATE (MegR:Person {name:'Meg Ryan', born:1961})
CREATE (TonyS:Person {name:'Tony Scott', born:1944})
CREATE (JimC:Person {name:'Jim Cash', born:1941})
CREATE
(TomC)-[:ACTED_IN {roles:['Maverick']}]->(TopGun),
(KellyM)-[:ACTED_IN {roles:['Charlie']}]->(TopGun),
(ValK)-[:ACTED_IN {roles:['Iceman']}]->(TopGun),
(AnthonyE)-[:ACTED_IN {roles:['Goose']}]->(TopGun),
(TomS)-[:ACTED_IN {roles:['Viper']}]->(TopGun),
(MegR)-[:ACTED_IN {roles:['Carole']}]->(TopGun),
(TonyS)-[:DIRECTED]->(TopGun),
(JimC)-[:WROTE]->(TopGun)

CREATE (JerryMaguire:Movie {title:'Jerry Maguire', released:2000, tagline:'The rest of his life begins now.'})
CREATE (ReneeZ:Person {name:'Renee Zellweger', born:1969})
CREATE (KellyP:Person {name:'Kelly Preston', born:1962})
CREATE (JerryO:Person {name:"Jerry O'Connell", born:1974})
CREATE (JayM:Person {name:'Jay Mohr', born:1970})
CREATE (BonnieH:Person {name:'Bonnie Hunt', born:1961})
CREATE (ReginaK:Person {name:'Regina King', born:1971})
CREATE (JonathanL:Person {name:'Jonathan Lipnicki', born:1996})
CREATE (CameronC:Person {name:'Cameron Crowe', born:1957})
CREATE
(TomC)-[:ACTED_IN {roles:['Jerry Maguire']}]->(JerryMaguire),
(CubaG)-[:ACTED_IN {roles:['Rod Tidwell']}]->(JerryMaguire),
(ReneeZ)-[:ACTED_IN {roles:['Dorothy Boyd']}]->(JerryMaguire),
(KellyP)-[:ACTED_IN {roles:['Avery Bishop']}]->(JerryMaguire),
(JerryO)-[:ACTED_IN {roles:['Frank Cushman']}]->(JerryMaguire),
(JayM)-[:ACTED_IN {roles:['Bob Sugar']}]->(JerryMaguire),
(BonnieH)-[:ACTED_IN {roles:['Laurel Boyd']}]->(JerryMaguire),
(ReginaK)-[:ACTED_IN {roles:['Marcee Tidwell']}]->(JerryMaguire),
(JonathanL)-[:ACTED_IN {roles:['Ray Boyd']}]->(JerryMaguire),
(CameronC)-[:DIRECTED]->(JerryMaguire),
(CameronC)-[:PRODUCED]->(JerryMaguire),
(CameronC)-[:WROTE]->(JerryMaguire)

CREATE (StandByMe:Movie {title:"Stand By Me", released:1986, tagline:"For some, it's the last real taste of innocence, and the first real taste of life. But for everyone, it's the time that memories are made of."})
CREATE (RiverP:Person {name:'River Phoenix', born:1970})
CREATE (CoreyF:Person {name:'Corey Feldman', born:1971})
CREATE (WilW:Person {name:'Wil Wheaton', born:1972})
CREATE (JohnC:Person {name:'John Cusack', born:1966})
CREATE (MarshallB:Person {name:'Marshall Bell', born:1942})
CREATE
(WilW)-[:ACTED_IN {roles:['Gordie Lachance']}]->(StandByMe),
(RiverP)-[:ACTED_IN {roles:['Chris Chambers']}]->(StandByMe),
(JerryO)-[:ACTED_IN {roles:['Vern Tessio']}]->(StandByMe),
(CoreyF)-[:ACTED_IN {roles:['Teddy Duchamp']}]->(StandByMe),
(JohnC)-[:ACTED_IN {roles:['Denny Lachance']}]->(StandByMe),
(KieferS)-[:ACTED_IN {roles:['Ace Merrill']}]->(StandByMe),
(MarshallB)-[:ACTED_IN {roles:['Mr. Lachance']}]->(StandByMe),
(RobR)-[:DIRECTED]->(StandByMe)

CREATE (AsGoodAsItGets:Movie {title:'As Good as It Gets', released:1997, tagline:'A comedy from the heart that goes for the throat.'})
CREATE (HelenH:Person {name:'Helen Hunt', born:1963})
CREATE (GregK:Person {name:'Greg Kinnear', born:1963})
CREATE (JamesB:Person {name:'James L. Brooks', born:1940})
CREATE
(JackN)-[:ACTED_IN {roles:['Melvin Udall']}]->(AsGoodAsItGets),
(HelenH)-[:ACTED_IN {roles:['Carol Connelly']}]->(AsGoodAsItGets),
(GregK)-[:ACTED_IN {roles:['Simon Bishop']}]->(AsGoodAsItGets),
(CubaG)-[:ACTED_IN {roles:['Frank Sachs']}]->(AsGoodAsItGets),
(JamesB)-[:DIRECTED]->(AsGoodAsItGets)

CREATE (WhatDreamsMayCome:Movie {title:'What Dreams May Come', released:1998, tagline:'After life there is more. The end is just the beginning.'})
CREATE (AnnabellaS:Person {name:'Annabella Sciorra', born:1960})
CREATE (MaxS:Person {name:'Max von Sydow', born:1929})
CREATE (WernerH:Person {name:'Werner Herzog', born:1942})
CREATE (Robin:Person {name:'Robin Williams', born:1951})
CREATE (VincentW:Person {name:'Vincent Ward', born:1956})
CREATE
(Robin)-[:ACTED_IN {roles:['Chris Nielsen']}]->(WhatDreamsMayCome),
(CubaG)-[:ACTED_IN {roles:['Albert Lewis']}]->(WhatDreamsMayCome),
(AnnabellaS)-[:ACTED_IN {roles:['Annie Collins-Nielsen']}]->(WhatDreamsMayCome),
(MaxS)-[:ACTED_IN {roles:['The Tracker']}]->(WhatDreamsMayCome),
(WernerH)-[:ACTED_IN {roles:['The Face']}]->(WhatDreamsMayCome),
(VincentW)-[:DIRECTED]->(WhatDreamsMayCome)

CREATE (SnowFallingonCedars:Movie {title:'Snow Falling on Cedars', released:1999, tagline:'First loves last. Forever.'})
CREATE (EthanH:Person {name:'Ethan Hawke', born:1970})
CREATE (RickY:Person {name:'Rick Yune', born:1971})
CREATE (JamesC:Person {name:'James Cromwell', born:1940})
CREATE (ScottH:Person {name:'Scott Hicks', born:1953})
CREATE
(EthanH)-[:ACTED_IN {roles:['Ishmael Chambers']}]->(SnowFallingonCedars),
(RickY)-[:ACTED_IN {roles:['Kazuo Miyamoto']}]->(SnowFallingonCedars),
(MaxS)-[:ACTED_IN {roles:['Nels Gudmundsson']}]->(SnowFallingonCedars),
(JamesC)-[:ACTED_IN {roles:['Judge Fielding']}]->(SnowFallingonCedars),
(ScottH)-[:DIRECTED]->(SnowFallingonCedars)

CREATE (YouveGotMail:Movie {title:"You've Got Mail", released:1998, tagline:'At odds in life... in love on-line.'})
CREATE (ParkerP:Person {name:'Parker Posey', born:1968})
CREATE (DaveC:Person {name:'Dave Chappelle', born:1973})
CREATE (SteveZ:Person {name:'Steve Zahn', born:1967})
CREATE (TomH:Person {name:'Tom Hanks', born:1956})
CREATE (NoraE:Person {name:'Nora Ephron', born:1941})
CREATE
(TomH)-[:ACTED_IN {roles:['Joe Fox']}]->(YouveGotMail),
(MegR)-[:ACTED_IN {roles:['Kathleen Kelly']}]->(YouveGotMail),
(GregK)-[:ACTED_IN {roles:['Frank Navasky']}]->(YouveGotMail),
(ParkerP)-[:ACTED_IN {roles:['Patricia Eden']}]->(YouveGotMail),
(DaveC)-[:ACTED_IN {roles:['Kevin Jackson']}]->(YouveGotMail),
(SteveZ)-[:ACTED_IN {roles:['George Pappas']}]->(YouveGotMail),
(NoraE)-[:DIRECTED]->(YouveGotMail)

CREATE (SleeplessInSeattle:Movie {title:'Sleepless in Seattle', released:1993, tagline:'What if someone you never met, someone you never saw, someone you never knew was the only someone for you?'})
CREATE (RitaW:Person {name:'Rita Wilson', born:1956})
CREATE (BillPull:Person {name:'Bill Pullman', born:1953})
CREATE (VictorG:Person {name:'Victor Garber', born:1949})
CREATE (RosieO:Person {name:"Rosie O'Donnell", born:1962})
CREATE
(TomH)-[:ACTED_IN {roles:['Sam Baldwin']}]->(SleeplessInSeattle),
(MegR)-[:ACTED_IN {roles:['Annie Reed']}]->(SleeplessInSeattle),
(RitaW)-[:ACTED_IN {roles:['Suzy']}]->(SleeplessInSeattle),
(BillPull)-[:ACTED_IN {roles:['Walter']}]->(SleeplessInSeattle),
(VictorG)-[:ACTED_IN {roles:['Greg']}]->(SleeplessInSeattle),
(RosieO)-[:ACTED_IN {roles:['Becky']}]->(SleeplessInSeattle),
(NoraE)-[:DIRECTED]->(SleeplessInSeattle)

CREATE (JoeVersustheVolcano:Movie {title:'Joe Versus the Volcano', released:1990, tagline:'A story of love, lava and burning desire.'})
CREATE (JohnS:Person {name:'John Patrick Stanley', born:1950})
CREATE (Nathan:Person {name:'Nathan Lane', born:1956})
CREATE
(TomH)-[:ACTED_IN {roles:['Joe Banks']}]->(JoeVersustheVolcano),
(MegR)-[:ACTED_IN {roles:['DeDe', 'Angelica Graynamore', 'Patricia Graynamore']}]->(JoeVersustheVolcano),
(Nathan)-[:ACTED_IN {roles:['Baw']}]->(JoeVersustheVolcano),
(JohnS)-[:DIRECTED]->(JoeVersustheVolcano)

CREATE (WhenHarryMetSally:Movie {title:'When Harry Met Sally', released:1998, tagline:'Can two friends sleep together and still love each other in the morning?'})
CREATE (BillyC:Person {name:'Billy Crystal', born:1948})
CREATE (CarrieF:Person {name:'Carrie Fisher', born:1956})
CREATE (BrunoK:Person {name:'Bruno Kirby', born:1949})
CREATE
(BillyC)-[:ACTED_IN {roles:['Harry Burns']}]->(WhenHarryMetSally),
(MegR)-[:ACTED_IN {roles:['Sally Albright']}]->(WhenHarryMetSally),
(CarrieF)-[:ACTED_IN {roles:['Marie']}]->(WhenHarryMetSally),
(BrunoK)-[:ACTED_IN {roles:['Jess']}]->(WhenHarryMetSally),
(RobR)-[:DIRECTED]->(WhenHarryMetSally),
(RobR)-[:PRODUCED]->(WhenHarryMetSally),
(NoraE)-[:PRODUCED]->(WhenHarryMetSally),
(NoraE)-[:WROTE]->(WhenHarryMetSally)

CREATE (ThatThingYouDo:Movie {title:'That Thing You Do', released:1996, tagline:'In every life there comes a time when that thing you dream becomes that thing you do'})
CREATE (LivT:Person {name:'Liv Tyler', born:1977})
CREATE
(TomH)-[:ACTED_IN {roles:['Mr. White']}]->(ThatThingYouDo),
(LivT)-[:ACTED_IN {roles:['Faye Dolan']}]->(ThatThingYouDo),
(Charlize)-[:ACTED_IN {roles:['Tina']}]->(ThatThingYouDo),
(TomH)-[:DIRECTED]->(ThatThingYouDo)

CREATE (TheReplacements:Movie {title:'The Replacements', released:2000, tagline:'Pain heals, Chicks dig scars... Glory lasts forever'})
CREATE (Brooke:Person {name:'Brooke Langton', born:1970})
CREATE (Gene:Person {name:'Gene Hackman', born:1930})
CREATE (Orlando:Person {name:'Orlando Jones', born:1968})
CREATE (Howard:Person {name:'Howard Deutch', born:1950})
CREATE
(Keanu)-[:ACTED_IN {roles:['Shane Falco']}]->(TheReplacements),
(Brooke)-[:ACTED_IN {roles:['Annabelle Farrell']}]->(TheReplacements),
(Gene)-[:ACTED_IN {roles:['Jimmy McGinty']}]->(TheReplacements),
(Orlando)-[:ACTED_IN {roles:['Clifford Franklin']}]->(TheReplacements),
(Howard)-[:DIRECTED]->(TheReplacements)

CREATE (RescueDawn:Movie {title:'RescueDawn', released:2006, tagline:"Based on the extraordinary true story of one man's fight for freedom"})
CREATE (ChristianB:Person {name:'Christian Bale', born:1974})
CREATE (ZachG:Person {name:'Zach Grenier', born:1954})
CREATE
(MarshallB)-[:ACTED_IN {roles:['Admiral']}]->(RescueDawn),
(ChristianB)-[:ACTED_IN {roles:['Dieter Dengler']}]->(RescueDawn),
(ZachG)-[:ACTED_IN {roles:['Squad Leader']}]->(RescueDawn),
(SteveZ)-[:ACTED_IN {roles:['Duane']}]->(RescueDawn),
(WernerH)-[:DIRECTED]->(RescueDawn)

CREATE (TheBirdcage:Movie {title:'The Birdcage', released:1996, tagline:'Come as you are'})
CREATE (MikeN:Person {name:'Mike Nichols', born:1931})
CREATE
(Robin)-[:ACTED_IN {roles:['Armand Goldman']}]->(TheBirdcage),
(Nathan)-[:ACTED_IN {roles:['Albert Goldman']}]->(TheBirdcage),
(Gene)-[:ACTED_IN {roles:['Sen. Kevin Keeley']}]->(TheBirdcage),
(MikeN)-[:DIRECTED]->(TheBirdcage)

CREATE (Unforgiven:Movie {title:'Unforgiven', released:1992, tagline:"It's a hell of a thing, killing a man"})
CREATE (RichardH:Person {name:'Richard Harris', born:1930})
CREATE (ClintE:Person {name:'Clint Eastwood', born:1930})
CREATE
(RichardH)-[:ACTED_IN {roles:['English Bob']}]->(Unforgiven),
(ClintE)-[:ACTED_IN {roles:['Bill Munny']}]->(Unforgiven),
(Gene)-[:ACTED_IN {roles:['Little Bill Daggett']}]->(Unforgiven),
(ClintE)-[:DIRECTED]->(Unforgiven)

CREATE (JohnnyMnemonic:Movie {title:'Johnny Mnemonic', released:1995, tagline:'The hottest data on earth. In the coolest head in town'})
CREATE (Takeshi:Person {name:'Takeshi Kitano', born:1947})
CREATE (Dina:Person {name:'Dina Meyer', born:1968})
CREATE (IceT:Person {name:'Ice-T', born:1958})
CREATE (RobertL:Person {name:'Robert Longo', born:1953})
CREATE
(Keanu)-[:ACTED_IN {roles:['Johnny Mnemonic']}]->(JohnnyMnemonic),
(Takeshi)-[:ACTED_IN {roles:['Takahashi']}]->(JohnnyMnemonic),
(Dina)-[:ACTED_IN {roles:['Jane']}]->(JohnnyMnemonic),
(IceT)-[:ACTED_IN {roles:['J-Bone']}]->(JohnnyMnemonic),
(RobertL)-[:DIRECTED]->(JohnnyMnemonic)

CREATE (CloudAtlas:Movie {title:'Cloud Atlas', released:2012, tagline:'Everything is connected'})
CREATE (HalleB:Person {name:'Halle Berry', born:1966})
CREATE (JimB:Person {name:'Jim Broadbent', born:1949})
CREATE (TomT:Person {name:'Tom Tykwer', born:1965})
CREATE (DavidMitchell:Person {name:'David Mitchell', born:1969})
CREATE (StefanArndt:Person {name:'Stefan Arndt', born:1961})
CREATE
(TomH)-[:ACTED_IN {roles:['Zachry', 'Dr. Henry Goose', 'Isaac Sachs', 'Dermot Hoggins']}]->(CloudAtlas),
(Hugo)-[:ACTED_IN {roles:['Bill Smoke', 'Haskell Moore', 'Tadeusz Kesselring', 'Nurse Noakes', 'Boardman Mephi', 'Old Georgie']}]->(CloudAtlas),
(HalleB)-[:ACTED_IN {roles:['Luisa Rey', 'Jocasta Ayrs', 'Ovid', 'Meronym']}]->(CloudAtlas),
(JimB)-[:ACTED_IN {roles:['Vyvyan Ayrs', 'Captain Molyneux', 'Timothy Cavendish']}]->(CloudAtlas),
(TomT)-[:DIRECTED]->(CloudAtlas),
(LillyW)-[:DIRECTED]->(CloudAtlas),
(LanaW)-[:DIRECTED]->(CloudAtlas),
(DavidMitchell)-[:WROTE]->(CloudAtlas),
(StefanArndt)-[:PRODUCED]->(CloudAtlas)

CREATE (TheDaVinciCode:Movie {title:'The Da Vinci Code', released:2006, tagline:'Break The Codes'})
CREATE (IanM:Person {name:'Ian McKellen', born:1939})
CREATE (AudreyT:Person {name:'Audrey Tautou', born:1976})
CREATE (PaulB:Person {name:'Paul Bettany', born:1971})
CREATE (RonH:Person {name:'Ron Howard', born:1954})
CREATE
(TomH)-[:ACTED_IN {roles:['Dr. Robert Langdon']}]->(TheDaVinciCode),
(IanM)-[:ACTED_IN {roles:['Sir Leight Teabing']}]->(TheDaVinciCode),
(AudreyT)-[:ACTED_IN {roles:['Sophie Neveu']}]->(TheDaVinciCode),
(PaulB)-[:ACTED_IN {roles:['Silas']}]->(TheDaVinciCode),
(RonH)-[:DIRECTED]->(TheDaVinciCode)

CREATE (VforVendetta:Movie {title:'V for Vendetta', released:2006, tagline:'Freedom! Forever!'})
CREATE (NatalieP:Person {name:'Natalie Portman', born:1981})
CREATE (StephenR:Person {name:'Stephen Rea', born:1946})
CREATE (JohnH:Person {name:'John Hurt', born:1940})
CREATE (BenM:Person {name: 'Ben Miles', born:1967})
CREATE
(Hugo)-[:ACTED_IN {roles:['V']}]->(VforVendetta),
(NatalieP)-[:ACTED_IN {roles:['Evey Hammond']}]->(VforVendetta),
(StephenR)-[:ACTED_IN {roles:['Eric Finch']}]->(VforVendetta),
(JohnH)-[:ACTED_IN {roles:['High Chancellor Adam Sutler']}]->(VforVendetta),
(BenM)-[:ACTED_IN {roles:['Dascomb']}]->(VforVendetta),
(JamesM)-[:DIRECTED]->(VforVendetta),
(LillyW)-[:PRODUCED]->(VforVendetta),
(LanaW)-[:PRODUCED]->(VforVendetta),
(JoelS)-[:PRODUCED]->(VforVendetta),
(LillyW)-[:WROTE]->(VforVendetta),
(LanaW)-[:WROTE]->(VforVendetta)

CREATE (SpeedRacer:Movie {title:'Speed Racer', released:2008, tagline:'Speed has no limits'})
CREATE (EmileH:Person {name:'Emile Hirsch', born:1985})
CREATE (JohnG:Person {name:'John Goodman', born:1960})
CREATE (SusanS:Person {name:'Susan Sarandon', born:1946})
CREATE (MatthewF:Person {name:'Matthew Fox', born:1966})
CREATE (ChristinaR:Person {name:'Christina Ricci', born:1980})
CREATE (Rain:Person {name:'Rain', born:1982})
CREATE
(EmileH)-[:ACTED_IN {roles:['Speed Racer']}]->(SpeedRacer),
(JohnG)-[:ACTED_IN {roles:['Pops']}]->(SpeedRacer),
(SusanS)-[:ACTED_IN {roles:['Mom']}]->(SpeedRacer),
(MatthewF)-[:ACTED_IN {roles:['Racer X']}]->(SpeedRacer),
(ChristinaR)-[:ACTED_IN {roles:['Trixie']}]->(SpeedRacer),
(Rain)-[:ACTED_IN {roles:['Taejo Togokahn']}]->(SpeedRacer),
(BenM)-[:ACTED_IN {roles:['Cass Jones']}]->(SpeedRacer),
(LillyW)-[:DIRECTED]->(SpeedRacer),
(LanaW)-[:DIRECTED]->(SpeedRacer),
(LillyW)-[:WROTE]->(SpeedRacer),
(LanaW)-[:WROTE]->(SpeedRacer),
(JoelS)-[:PRODUCED]->(SpeedRacer)

CREATE (NinjaAssassin:Movie {title:'Ninja Assassin', released:2009, tagline:'Prepare to enter a secret world of assassins'})
CREATE (NaomieH:Person {name:'Naomie Harris'})
CREATE
(Rain)-[:ACTED_IN {roles:['Raizo']}]->(NinjaAssassin),
(NaomieH)-[:ACTED_IN {roles:['Mika Coretti']}]->(NinjaAssassin),
(RickY)-[:ACTED_IN {roles:['Takeshi']}]->(NinjaAssassin),
(BenM)-[:ACTED_IN {roles:['Ryan Maslow']}]->(NinjaAssassin),
(JamesM)-[:DIRECTED]->(NinjaAssassin),
(LillyW)-[:PRODUCED]->(NinjaAssassin),
(LanaW)-[:PRODUCED]->(NinjaAssassin),
(JoelS)-[:PRODUCED]->(NinjaAssassin)

CREATE (TheGreenMile:Movie {title:'The Green Mile', released:1999, tagline:"Walk a mile you'll never forget."})
CREATE (MichaelD:Person {name:'Michael Clarke Duncan', born:1957})
CREATE (DavidM:Person {name:'David Morse', born:1953})
CREATE (SamR:Person {name:'Sam Rockwell', born:1968})
CREATE (GaryS:Person {name:'Gary Sinise', born:1955})
CREATE (PatriciaC:Person {name:'Patricia Clarkson', born:1959})
CREATE (FrankD:Person {name:'Frank Darabont', born:1959})
CREATE
(TomH)-[:ACTED_IN {roles:['Paul Edgecomb']}]->(TheGreenMile),
(MichaelD)-[:ACTED_IN {roles:['John Coffey']}]->(TheGreenMile),
(DavidM)-[:ACTED_IN {roles:['Brutus "Brutal" Howell']}]->(TheGreenMile),
(BonnieH)-[:ACTED_IN {roles:['Jan Edgecomb']}]->(TheGreenMile),
(JamesC)-[:ACTED_IN {roles:['Warden Hal Moores']}]->(TheGreenMile),
(SamR)-[:ACTED_IN {roles:['"Wild Bill" Wharton']}]->(TheGreenMile),
(GaryS)-[:ACTED_IN {roles:['Burt Hammersmith']}]->(TheGreenMile),
(PatriciaC)-[:ACTED_IN {roles:['Melinda Moores']}]->(TheGreenMile),
(FrankD)-[:DIRECTED]->(TheGreenMile)

CREATE (FrostNixon:Movie {title:'Frost/Nixon', released:2008, tagline:'400 million people were waiting for the truth.'})
CREATE (FrankL:Person {name:'Frank Langella', born:1938})
CREATE (MichaelS:Person {name:'Michael Sheen', born:1969})
CREATE (OliverP:Person {name:'Oliver Platt', born:1960})
CREATE
(FrankL)-[:ACTED_IN {roles:['Richard Nixon']}]->(FrostNixon),
(MichaelS)-[:ACTED_IN {roles:['David Frost']}]->(FrostNixon),
(KevinB)-[:ACTED_IN {roles:['Jack Brennan']}]->(FrostNixon),
(OliverP)-[:ACTED_IN {roles:['Bob Zelnick']}]->(FrostNixon),
(SamR)-[:ACTED_IN {roles:['James Reston, Jr.']}]->(FrostNixon),
(RonH)-[:DIRECTED]->(FrostNixon)

CREATE (Hoffa:Movie {title:'Hoffa', released:1992, tagline:"He didn't want law. He wanted justice."})
CREATE (DannyD:Person {name:'Danny DeVito', born:1944})
CREATE (JohnR:Person {name:'John C. Reilly', born:1965})
CREATE
(JackN)-[:ACTED_IN {roles:['Hoffa']}]->(Hoffa),
(DannyD)-[:ACTED_IN {roles:['Robert "Bobby" Ciaro']}]->(Hoffa),
(JTW)-[:ACTED_IN {roles:['Frank Fitzsimmons']}]->(Hoffa),
(JohnR)-[:ACTED_IN {roles:['Peter "Pete" Connelly']}]->(Hoffa),
(DannyD)-[:DIRECTED]->(Hoffa)

CREATE (Apollo13:Movie {title:'Apollo 13', released:1995, tagline:'Houston, we have a problem.'})
CREATE (EdH:Person {name:'Ed Harris', born:1950})
CREATE (BillPax:Person {name:'Bill Paxton', born:1955})
CREATE
(TomH)-[:ACTED_IN {roles:['Jim Lovell']}]->(Apollo13),
(KevinB)-[:ACTED_IN {roles:['Jack Swigert']}]->(Apollo13),
(EdH)-[:ACTED_IN {roles:['Gene Kranz']}]->(Apollo13),
(BillPax)-[:ACTED_IN {roles:['Fred Haise']}]->(Apollo13),
(GaryS)-[:ACTED_IN {roles:['Ken Mattingly']}]->(Apollo13),
(RonH)-[:DIRECTED]->(Apollo13)

CREATE (Twister:Movie {title:'Twister', released:1996, tagline:"Don't Breathe. Don't Look Back."})
CREATE (PhilipH:Person {name:'Philip Seymour Hoffman', born:1967})
CREATE (JanB:Person {name:'Jan de Bont', born:1943})
CREATE
(BillPax)-[:ACTED_IN {roles:['Bill Harding']}]->(Twister),
(HelenH)-[:ACTED_IN {roles:['Dr. Jo Harding']}]->(Twister),
(ZachG)-[:ACTED_IN {roles:['Eddie']}]->(Twister),
(PhilipH)-[:ACTED_IN {roles:['Dustin "Dusty" Davis']}]->(Twister),
(JanB)-[:DIRECTED]->(Twister)

CREATE (CastAway:Movie {title:'Cast Away', released:2000, tagline:'At the edge of the world, his journey begins.'})
CREATE (RobertZ:Person {name:'Robert Zemeckis', born:1951})
CREATE
(TomH)-[:ACTED_IN {roles:['Chuck Noland']}]->(CastAway),
(HelenH)-[:ACTED_IN {roles:['Kelly Frears']}]->(CastAway),
(RobertZ)-[:DIRECTED]->(CastAway)

CREATE (OneFlewOvertheCuckoosNest:Movie {title:"One Flew Over the Cuckoo's Nest", released:1975, tagline:"If he's crazy, what does that make you?"})
CREATE (MilosF:Person {name:'Milos Forman', born:1932})
CREATE
(JackN)-[:ACTED_IN {roles:['Randle McMurphy']}]->(OneFlewOvertheCuckoosNest),
(DannyD)-[:ACTED_IN {roles:['Martini']}]->(OneFlewOvertheCuckoosNest),
(MilosF)-[:DIRECTED]->(OneFlewOvertheCuckoosNest)

CREATE (SomethingsGottaGive:Movie {title:"Something's Gotta Give", released:2003})
CREATE (DianeK:Person {name:'Diane Keaton', born:1946})
CREATE (NancyM:Person {name:'Nancy Meyers', born:1949})
CREATE
(JackN)-[:ACTED_IN {roles:['Harry Sanborn']}]->(SomethingsGottaGive),
(DianeK)-[:ACTED_IN {roles:['Erica Barry']}]->(SomethingsGottaGive),
(Keanu)-[:ACTED_IN {roles:['Julian Mercer']}]->(SomethingsGottaGive),
(NancyM)-[:DIRECTED]->(SomethingsGottaGive),
(NancyM)-[:PRODUCED]->(SomethingsGottaGive),
(NancyM)-[:WROTE]->(SomethingsGottaGive)

CREATE (BicentennialMan:Movie {title:'Bicentennial Man', released:1999, tagline:"One robot's 200 year journey to become an ordinary man."})
CREATE (ChrisC:Person {name:'Chris Columbus', born:1958})
CREATE
(Robin)-[:ACTED_IN {roles:['Andrew Marin']}]->(BicentennialMan),
(OliverP)-[:ACTED_IN {roles:['Rupert Burns']}]->(BicentennialMan),
(ChrisC)-[:DIRECTED]->(BicentennialMan)

CREATE (CharlieWilsonsWar:Movie {title:"Charlie Wilson's War", released:2007, tagline:"A stiff drink. A little mascara. A lot of nerve. Who said they couldn't bring down the Soviet empire."})
CREATE (JuliaR:Person {name:'Julia Roberts', born:1967})
CREATE
(TomH)-[:ACTED_IN {roles:['Rep. Charlie Wilson']}]->(CharlieWilsonsWar),
(JuliaR)-[:ACTED_IN {roles:['Joanne Herring']}]->(CharlieWilsonsWar),
(PhilipH)-[:ACTED_IN {roles:['Gust Avrakotos']}]->(CharlieWilsonsWar),
(MikeN)-[:DIRECTED]->(CharlieWilsonsWar)

CREATE (ThePolarExpress:Movie {title:'The Polar Express', released:2004, tagline:'This Holiday Season... Believe'})
CREATE
(TomH)-[:ACTED_IN {roles:['Hero Boy', 'Father', 'Conductor', 'Hobo', 'Scrooge', 'Santa Claus']}]->(ThePolarExpress),
(RobertZ)-[:DIRECTED]->(ThePolarExpress)

CREATE (ALeagueofTheirOwn:Movie {title:'A League of Their Own', released:1992, tagline:'Once in a lifetime you get a chance to do something different.'})
CREATE (Madonna:Person {name:'Madonna', born:1954})
CREATE (GeenaD:Person {name:'Geena Davis', born:1956})
CREATE (LoriP:Person {name:'Lori Petty', born:1963})
CREATE (PennyM:Person {name:'Penny Marshall', born:1943})
CREATE
(TomH)-[:ACTED_IN {roles:['Jimmy Dugan']}]->(ALeagueofTheirOwn),
(GeenaD)-[:ACTED_IN {roles:['Dottie Hinson']}]->(ALeagueofTheirOwn),
(LoriP)-[:ACTED_IN {roles:['Kit Keller']}]->(ALeagueofTheirOwn),
(RosieO)-[:ACTED_IN {roles:['Doris Murphy']}]->(ALeagueofTheirOwn),
(Madonna)-[:ACTED_IN {roles:['"All the Way" Mae Mordabito']}]->(ALeagueofTheirOwn),
(BillPax)-[:ACTED_IN {roles:['Bob Hinson']}]->(ALeagueofTheirOwn),
(PennyM)-[:DIRECTED]->(ALeagueofTheirOwn)

CREATE (PaulBlythe:Person {name:'Paul Blythe'})
CREATE (AngelaScope:Person {name:'Angela Scope'})
CREATE (JessicaThompson:Person {name:'Jessica Thompson'})
CREATE (JamesThompson:Person {name:'James Thompson'})

CREATE
(JamesThompson)-[:FOLLOWS]->(JessicaThompson),
(AngelaScope)-[:FOLLOWS]->(JessicaThompson),
(PaulBlythe)-[:FOLLOWS]->(AngelaScope)

CREATE
(JessicaThompson)-[:REVIEWED {summary:'An amazing journey', rating:95}]->(CloudAtlas),
(JessicaThompson)-[:REVIEWED {summary:'Silly, but fun', rating:65}]->(TheReplacements),
(JamesThompson)-[:REVIEWED {summary:'The coolest football movie ever', rating:100}]->(TheReplacements),
(AngelaScope)-[:REVIEWED {summary:'Pretty funny at times', rating:62}]->(TheReplacements),
(JessicaThompson)-[:REVIEWED {summary:'Dark, but compelling', rating:85}]->(Unforgiven),
(JessicaThompson)-[:REVIEWED {summary:"Slapstick redeemed only by the Robin Williams and Gene Hackman's stellar performances", rating:45}]->(TheBirdcage),
(JessicaThompson)-[:REVIEWED {summary:'A solid romp', rating:68}]->(TheDaVinciCode),
(JamesThompson)-[:REVIEWED {summary:'Fun, but a little far fetched', rating:65}]->(TheDaVinciCode),
(JessicaThompson)-[:REVIEWED {summary:'You had me at Jerry', rating:92}]->(JerryMaguire)

WITH TomH as a
MATCH (a)-[:ACTED_IN]->(m)<-[:DIRECTED]-(d) RETURN a,m,d LIMIT 10;

:play movies

:guide intro

:server connect

:guide intro

call dbms.components();

:guide intro

:play https://guides.neo4j.com/graph-examples/bank-fraud-detection/graph_guide

MATCH (n) RETURN n LIMIT 25;

MATCH (n:Author) RETURN n LIMIT 25;

MATCH (n) RETURN n LIMIT 25;

match (a) detach delete a;

MATCH (n:Book) RETURN n LIMIT 25;

:guide intro

MATCH (n) RETURN n LIMIT 25;

match (a:Address) detach delete a;

match (a:Order) detach delete a;

MATCH (n) RETURN n LIMIT 25;

MATCH (n:Customer) RETURN n LIMIT 25;

:params

WITH 'root_' + $cypherParams.rootOrganizationId as rootOrgLabel, 'org_' + $cypherParams.organizationId as orgLabel
      MATCH(schedule:Schedule{id:$input.scheduleId})-[:IN_TERM]->(term:Term{id:$input.termId})
      WHERE apoc.coll.contains(labels(schedule), orgLabel)
      MERGE(term)-[:HAS_ALLOCATION_PLAN]->(aPlan:AllocationPlan)
    WITH schedule , term, aPlan, orgLabel, rootOrgLabel
      CALL apoc.create.addLabels(aPlan, [orgLabel, rootOrgLabel]) YIELD node
    WITH schedule, term, aPlan
      UNWIND $input.plan as newAllocation
        OPTIONAL MATCH(aPlan)-[oldRel:SCHEDULE_ALLOCATION {weekNumber: newAllocation.weekNumber}]-(schedule)
        DELETE oldRel
        MERGE(aPlan)-[rel:SCHEDULE_ALLOCATION {weekNumber: newAllocation.weekNumber, published: newAllocation.published}]-(schedule)
    WITH COLLECT(rel) as rels
    RETURN rels;

:param "cypherParams": {
      "rootOrganizationId": "c163bc2d-0aa4-4063-bb8f-99706e1ac2f0",
      "organizationId": "0d9aaa56-6180-426b-bcc7-f06164e3f257"
    }

WITH 'root_' + $cypherParams.rootOrganizationId as rootOrgLabel, 'org_' + $cypherParams.organizationId as orgLabel
      MATCH(schedule:Schedule{id:$input.scheduleId})-[:IN_TERM]->(term:Term{id:$input.termId})
      WHERE apoc.coll.contains(labels(schedule), orgLabel)
      MERGE(term)-[:HAS_ALLOCATION_PLAN]->(aPlan:AllocationPlan)
    WITH schedule , term, aPlan, orgLabel, rootOrgLabel
      CALL apoc.create.addLabels(aPlan, [orgLabel, rootOrgLabel]) YIELD node
    WITH schedule, term, aPlan
      UNWIND $input.plan as newAllocation
        OPTIONAL MATCH(aPlan)-[oldRel:SCHEDULE_ALLOCATION {weekNumber: newAllocation.weekNumber}]-(schedule)
        DELETE oldRel
        MERGE(aPlan)-[rel:SCHEDULE_ALLOCATION {weekNumber: newAllocation.weekNumber, published: newAllocation.published}]-(schedule)
    WITH COLLECT(rel) as rels
    RETURN rels;

explain
 WITH 'root_' + $cypherParams.rootOrganizationId as rootOrgLabel, 'org_' + $cypherParams.organizationId as orgLabel
      MATCH(schedule:Schedule{id:$input.scheduleId})-[:IN_TERM]->(term:Term{id:$input.termId})
      WHERE apoc.coll.contains(labels(schedule), orgLabel)
      MERGE(term)-[:HAS_ALLOCATION_PLAN]->(aPlan:AllocationPlan)
    WITH schedule , term, aPlan, orgLabel, rootOrgLabel
      CALL apoc.create.addLabels(aPlan, [orgLabel, rootOrgLabel]) YIELD node
    WITH schedule, term, aPlan
      UNWIND $input.plan as newAllocation
        OPTIONAL MATCH(aPlan)-[oldRel:SCHEDULE_ALLOCATION {weekNumber: newAllocation.weekNumber}]-(schedule)
        DELETE oldRel
        MERGE(aPlan)-[rel:SCHEDULE_ALLOCATION {weekNumber: newAllocation.weekNumber, published: newAllocation.published}]-(schedule)
    WITH COLLECT(rel) as rels
    RETURN rels;

:param "input": {
      "scheduleId": "c163bc2d-0aa4-4063-bb8f-99706e1ac2f0",
      "termId": "0d9aaa56-6180-426b-bcc7-f06164e3f257",
      "plan": [{ weekNumber: 202101, published: true }]
    }

:param "input": {
      "scheduleId": "c163bc2d-0aa4-4063-bb8f-99706e1ac2f0"
      "termId": "0d9aaa56-6180-426b-bcc7-f06164e3f257"
      "plan": [{ weekNumber: 202101, published: true }]
    }

:guide intro

MATCH (n:Author) RETURN n LIMIT 25;

MATCH (n:Book) RETURN n LIMIT 25;

MATCH (n:Author) RETURN n LIMIT 25;

:use neo4j

:use system

MATCH (n) RETURN n LIMIT 25;

match (n) detach delete n;

MATCH (n) RETURN n LIMIT 25;

:guide intro

MATCH ()<--(r:Response) with r, count(*) as rCount
MATCH (p:Product)<--(:Complaint)<--(r)
RETURN p.name, r.name, count(*) as c, (count(*)*100)/rCount as percent ORDER BY percent DESC LIMIT 10;

MATCH (sub:SubIssue)-[:IN_CATEGORY]->(i:Issue)
WITH sub, COLLECT(i.name) AS issues
WHERE size(issues) > 1
RETURN sub.name, issues LIMIT 2;

MATCH (sub:SubIssue)-[:IN_CATEGORY]->(i:Issue)
WITH sub, COLLECT(i.name) AS issues
WHERE size(issues) > 1
RETURN sub.name, issues;

MATCH (ef:Company {name:'EQUIFAX, INC.'})
MATCH (complaint:Complaint)-[:AGAINST]->(ef)
MATCH (:Response)-[:TO]->(complaint)
MATCH (complaint)-[:ABOUT]->(p:Product)
MATCH (complaint)-[:WITH]->(i:Issue)
RETURN p.name AS product, i.name AS issue, COUNT(*) AS count
ORDER BY count DESC LIMIT 2;

MATCH ()<--(r:Response) with r, count(*) as rCount
MATCH (p:Product)<--(:Complaint)<--(r)
RETURN p.name, r.name, count(*) as c, (count(*)*100)/rCount as percent ORDER BY percent DESC LIMIT 10;

MATCH (r:Response)-[:TO]->(:Complaint)
RETURN r.name AS response, COUNT(*) AS count
ORDER BY count DESC;

call apoc.meta.graph;

MATCH (i:Issue {name:'COMMUNICATION TACTICS'})
MATCH (sub:SubIssue)-[:IN_CATEGORY]->(i)
RETURN sub.name AS subissue
ORDER BY subissue;

MATCH (wf:Company {name:'EQUIFAX, INC.'})
MATCH (complaint:Complaint)-[:AGAINST]->(wf)
MATCH (:Response)-[:TO]->(complaint)
MATCH (complaint)-[:ABOUT]->(p:Product)
MATCH (complaint)-[:WITH]->(i:Issue)
RETURN p.name AS product, i.name AS issue, COUNT(*) AS count
ORDER BY count DESC LIMIT 5;

MATCH (sub:SubIssue)-[:IN_CATEGORY]->(i:Issue)
WITH sub, COLLECT(i.name) AS issues
WHERE size(issues) > 1
RETURN sub.name, issues;

MATCH (sub:SubIssue)-[:IN_CATEGORY]->(i:Issue)
WITH sub, COLLECT(i) AS issues
WHERE size(issues) > 1
RETURN sub, issues;

MATCH (ef:Company {name:'EQUIFAX, INC.'})
MATCH (complaint:Complaint)-[:AGAINST]->(ef)
MATCH (:Response)-[:TO]->(complaint)
MATCH (complaint)-[:ABOUT]->(p:Product)
MATCH (complaint)-[:WITH]->(i:Issue)
RETURN p.name AS product, i.name AS issue, COUNT(*) AS count
ORDER BY count DESC LIMIT 5;

MATCH (subIssue:SubIssue)
WHERE subIssue.name contains 'OBSCENE'
MATCH (complaint:Complaint)-[:WITH]->(subIssue)
MATCH (complaint)-[:ABOUT]->(p:Product)
OPTIONAL MATCH (complaint)-[:ABOUT]->(sub:SubProduct)
RETURN p.name AS product, sub.name AS subproduct, COUNT(*) AS count
ORDER BY count DESC;

MATCH (n:Complaint)-[:WITH]->(iss:Issue) 
RETURN n.state, iss.name, count(*) as c
ORDER BY c DESC LIMIT 5;

MATCH (n:Company)<-[:AGAINST]-()
RETURN n.name, count(*) AS c 
ORDER BY c DESC LIMIT 5;

MATCH (n:Company)<-[:AGAINST]-()
RETURN n.name, count(*) AS c 
ORDER BY c DESC LIMIT 10;

:history

MATCH (subIssue:SubIssue)
where subIssue.name contains 'OBSCENE'
MATCH (complaint:Complaint)-[:WITH]->(subIssue)
MATCH (complaint)-[:ABOUT]->(p:Product)
OPTIONAL MATCH (complaint)-[:ABOUT]->(sub:SubProduct)
RETURN p.name AS product, sub.name AS subproduct, COUNT(*) AS count
ORDER BY count DESC;

)
where subIssue.name contains 'OBSCENE'
MATCH (complaint:Complaint)-[:WITH]->(subIssue)
MATCH (complaint)-[:ABOUT]->(p:Product)
OPTIONAL MATCH (complaint)-[:ABOUT]->(sub:SubProduct)
RETURN p.name AS product, sub.name AS subproduct, COUNT(*) AS count
ORDER BY count DESC;

MATCH (ef:Company {name:'EQUIFAX, INC.'})
MATCH (complaint:Complaint)-[:AGAINST]->(ef)
MATCH (:Response)-[:TO]->(complaint)
MATCH (complaint)-[:ABOUT]->(p:Product)
MATCH (complaint)-[:WITH]->(i:Issue)
RETURN p.name AS product, i.name AS issue, COUNT(*) AS count
ORDER BY count DESC LIMIT 5;

MATCH (sub:SubIssue)-[:IN_CATEGORY]->(i:Issue)
WITH sub, COLLECT(i) AS issues
WHERE size(issues) > 1
RETURN sub, issues;

MATCH (sub:SubIssue)-[:IN_CATEGORY]->(i:Issue)
WITH sub, COLLECT(i) AS issues
WHERE LENGTH(issues) > 1
RETURN sub, issues;

profile MATCH (sub:SubProduct)-[:IN_CATEGORY]->(p:Product)
WITH sub, COLLECT(p) AS products
WHERE size(products) > 1
RETURN sub, products;

MATCH (sub:SubProduct)-[:IN_CATEGORY]->(p:Product)
WITH sub, COLLECT(p) AS products
WHERE size(products) > 1
RETURN sub, products;

MATCH (sub:SubProduct)-[:IN_CATEGORY]->(p:Product)
WITH sub, COLLECT(p) AS products
WHERE LENGTH(products) > 1
RETURN sub, products;

profile MATCH (wf:Company {name:'EQUIFAX, INC.'})
MATCH (complaint:Complaint)-[:AGAINST]->(wf)
MATCH (:Response)-[:TO]->(complaint)
MATCH (complaint)-[:ABOUT]->(p:Product)
MATCH (complaint)-[:WITH]->(i:Issue)
RETURN p.name AS product, i.name AS issue, COUNT(*) AS count
ORDER BY count DESC LIMIT 5;

profile MATCH (wf:Company {name:'EQUIFAX, INC.'})
MATCH (complaint:Complaint)-[:AGAINST]->(wf)
MATCH (:Response)-[:TO]->(complaint)
MATCH (complaint)-[:ABOUT]->(p:Product)
MATCH (complaint)-[:WITH]->(i:Issue)
RETURN p.name AS product, i.name AS issue, COUNT(*) AS count
ORDER BY count DESC;

MATCH (wf:Company) return wf;

MATCH (wf:Company {name:'EQUIFAX'}) return wf;

profile MATCH (wf:Company {name:'EQUIFAX'})
MATCH (complaint:Complaint)-[:AGAINST]->(wf)
RETURN count(*);

profile MATCH (wf:Company {name:'EQUIFAX'})
MATCH (complaint:Complaint)-[:AGAINST]->(wf)
MATCH (:Response)-[:TO]->(complaint)
MATCH (complaint)-[:ABOUT]->(p:Product)
MATCH (complaint)-[:WITH]->(i:Issue)
RETURN p.name AS product, i.name AS issue, COUNT(*) AS count
ORDER BY count DESC;

profile MATCH (wf:Company {name:'WELLS FARGO'})
MATCH (complaint:Complaint)-[:AGAINST]->(wf)
MATCH (:Response)-[:TO]->(complaint)
MATCH (complaint)-[:ABOUT]->(p:Product)
MATCH (complaint)-[:WITH]->(i:Issue)
RETURN p.name AS product, i.name AS issue, COUNT(*) AS count
ORDER BY count DESC;

MATCH (wf:Company {name:'WELLS FARGO'})
MATCH (complaint:Complaint)-[:AGAINST]->(wf)
MATCH (:Response)-[:TO]->(complaint)
MATCH (complaint)-[:ABOUT]->(p:Product)
MATCH (complaint)-[:WITH]->(i:Issue)
RETURN p.name AS product, i.name AS issue, COUNT(*) AS count
ORDER BY count DESC;

MATCH (wf:Company {name:'WELLS FARGO'})
MATCH (complaint:Complaint)-[:AGAINST]->(wf)
MATCH (:Response)-[:TO {disputed:true}]->(complaint)
MATCH (complaint)-[:ABOUT]->(p:Product)
MATCH (complaint)-[:WITH]->(i:Issue)
RETURN p.name AS product, i.name AS issue, COUNT(*) AS count
ORDER BY count DESC;

MATCH (subIssue:SubIssue {name:'USED OBSCENE/PROFANE/ABUSIVE LANGUAGE'})
MATCH (complaint:Complaint)-[:WITH]->(subIssue)
MATCH (complaint)-[:ABOUT]->(p:Product)
OPTIONAL MATCH (complaint)-[:ABOUT]->(sub:SubProduct)
RETURN p.name AS product, sub.name AS subproduct, COUNT(*) AS count
ORDER BY count DESC;

MATCH (i:Issue {name:'COMMUNICATION TACTICS'})
MATCH (sub:SubIssue)-[:IN_CATEGORY]->(i)
RETURN sub.name AS subissue
ORDER BY subissue;

MATCH (r:Response)-[:TO]->(:Complaint)
RETURN r.name AS response, COUNT(*) AS count
ORDER BY count DESC;

MATCH (r:Response)-[:TO {disputed:true}]->(:Complaint)
RETURN r.name AS response, COUNT(*) AS count
ORDER BY count DESC;

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})
match (co:Company {name:toUpper(row.Company)})
WITH * WHERE trim(row.`Company response to consumer`) <> ""

merge (res:Response {name:toUpper(row.`Company response to consumer`)})
merge (c)<-[rel:TO]-(res)
set rel.disputed = (row.`Consumer disputed?` = "Yes")
set rel.timely = (row.`Timely response?` = "Yes")
set rel.text = case row.`Company public response` when "" then null else row.`Company public response` end
merge (co)-[:ANSWERED]->(res);

:history

MATCH (r:Response)-[:TO {disputed:true}]->(:Complaint)
RETURN r.name AS response, COUNT(*) AS count
ORDER BY count DESC;

match ()<--(r:Response) with r, count(*) as rCount
match (p:Product)<--(:Complaint)<--(r)
return p.name, r.name, count(*) as c, (count(*)*100)/rCount as percent order by percent desc limit 10;

match ()<--(r:Response) with r, count(*) as rCount
match (p:Product)<--(:Complaint)<--(r)
return p.name, r.name, count(*) as c, (count(*)*100)/rCount as percent order by c desc limit 10;

match ()<--(r:Response) with r, count(*) as rCount
match (p:Product)<--(:Complaint)<--(r)
return p.name, r.name, count(*) as c, rCount as percent order by c desc limit 10;

match (r:Response) with r, count(*) as rCount
match (p:Product)<--(:Complaint)<--(r)
return p.name, r.name, count(*) as c, rCount as percent order by c desc limit 10;

match (r:Response) with r, count(*) as rCount
match (p:Product)<--(:Complaint)<--(r)
return p.name, r.name, count(*) as c, count(*)*100/rCount as percent order by c desc limit 10;

match (r:Response) with r, count(*) as rCount
match (p:Product)<--(:Complaint)<--(r)
return p.name, r.name, count(*) as c, c*100/rCount as percent order by c desc limit 10;

match (r:Response) with r, count(*) as rCount
match (p:Product)<--(c:Complaint)<--(r)
return p.name, r.name, count(*) as c, c*100/rCount as percent order by c desc limit 10;

match (p:Product)<--(c:Complaint)<--(r:Response)
return p.name, r.name, count(*) as c order by c desc limit 10;

call apoc.meta.graph;

call db.schema.visualization;

MATCH (n:Tag) RETURN n LIMIT 25;

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})

WITH * WHERE trim(row.`Tags`) <> ""
WITH distinct row.Tags as tagsName,c
UNWIND split(tagsName,", ") as tagName

merge (t:Tag {name:toUpper(tagName)})
merge (c)-[:TAGGED]->(t);

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})

WITH * WHERE trim(row.`Tags`) <> ""
WITH c, distinct row.Tags as tagsName
UNWIND split(tagsName,", ") as tagName

merge (t:Tag {name:toUpper(tagName)})
merge (c)-[:TAGGED]->(t);

:history

MATCH (n:Tag) Detach delete n;

MATCH (n:Tag) RETURN n LIMIT 25;

call db.schema.visualization();

MATCH p=()-[r:TO]->() where not r.text is null RETURN p LIMIT 25;

MATCH p=()-[r:TO]->() RETURN p LIMIT 25;

MATCH (n:Complaint) RETURN n LIMIT 1;

MATCH (n:Complaint) RETURN n LIMIT 25;

MATCH (n:Response) RETURN n LIMIT 25;

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})
match (co:Company {name:toUpper(row.Company)})
WITH * WHERE trim(row.`Company response to consumer`) <> ""

merge (res:Response {name:toUpper(row.`Company response to consumer`)})
merge (c)<-[rel:TO]-(res)
set rel.timely = (row.`Timely response?` = "Yes")
set rel.text = case row.`Company public response` when "" then null else row.`Company public response` end
merge (co)-[:ANSWERED]->(res);

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})
match (co:Company {name:toUpper(row.Company)})
WITH * WHERE trim(row.`Company response to consumer`) <> ""

merge (res:Response {name:toUpper(row.`Company response to consumer`)})
merge (c)<-[rel:TO]-(res)
set rel.timely = (row.`Timely response?` == "Yes")
set rel.text = case row.`Company public response` when "" then null else row.`Company public response` end
merge (co)-[:ANSWERED]->(res);

MATCH (n:Tag) RETURN n LIMIT 25;

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})

WITH * WHERE trim(row.`Tags`) <> ""
WITH distinct row.Tags as tagsName
UNWIND split(tagsName,", ") as tagName

merge (t:Tag {name:toUpper(tagName)})
merge (c)-[:TAGGED]->(t);

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})

WITH * WHERE trim(row.`Tags`) <> ""
WITH distinct row.Tags as tagsName
RETURN split(tagsName,", ") as tagName;

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})

WITH * WHERE trim(row.`Tags`) <> ""

RETURN distinct row.Tags;

MATCH (n:Tag) detach delete n;

MATCH (n:Tag) RETURN n LIMIT 25;

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})

WITH * WHERE trim(row.`Tags`) <> ""

merge (t:Tag {name:toUpper(row.Tags)})
merge (c)-[:TAGGED]->(t);

MATCH (n:Complaint) RETURN n LIMIT 1;

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})

merge (p:Product {name:toUpper(row.Product)})
merge (c)-[:ABOUT]->(p) 

WITH * WHERE trim(row.`Sub-product`) <> ""

merge (sp:SubProduct {name:toUpper(row.`Sub-product`)})
merge (c)-[:ABOUT]->(sp) 
merge (sp)-[:IN_CATEGORY]->(p);

MATCH (n:Complaint)-[:WITH]->(iss:Issue) 
RETURN n.state, iss.name, count(*) as c
ORDER BY c desc limit 10;

MATCH (n:Complaint) RETURN n LIMIT 1;

MATCH (n:Complaint) RETURN n LIMIT 25;

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})

merge (iss:Issue {name:toUpper(row.Issue)})
merge (c)-[:WITH]->(iss) 

WITH * WHERE trim(row.`Sub-issue`) <> ""

merge (si:SubIssue {name:toUpper(row.`Sub-issue`)})
merge (c)-[:WITH]->(si) 
merge (si)-[:IN_CATEGORY]->(iss);

MATCH p=()-[r:AGAINST]->() RETURN p LIMIT 25;

MATCH (n:Company)<-[:AGAINST]-()
RETURN n.name, count(*) as c 
ORDER BY c DESC LIMIT 10;

MATCH (n:Company) RETURN n LIMIT 25;

load csv with headers from "https://git.io/J1m7e" as row

match (c:Complaint {id:row.`Complaint ID`})

merge (co:Company {name:toUpper(row.Company)})

merge (c)-[rel:AGAINST]->(co) 
set rel.date = date(row.`Date sent to company`);

load csv with headers from "https://git.io/J1m7e" as row
match (c:Complaint {id:row.`Complaint ID`})
return count(*);

MATCH (n:Complaint) RETURN n LIMIT 25;

load csv with headers from "https://git.io/J1m7e" as row
merge (c:Complaint {id:row.`Complaint ID`})
set c.dateReceived = date(row.`Date received`) 
set c.zip = row.`ZIP code`
set c.state = row.State;

load csv with headers from "https://git.io/J1m7e" as row
return count(*);

:load csv with headers from "https://git.io/J1m7e" as row
return count(*)

:schema

create constraint on (c:Company) assert c.name is unique;

create constraint on (c:Response) assert c.name is unique;

create constraint on (c:Tag) assert c.name is unique;

create constraint on (c:SubProduct) assert c.name is unique;

create constraint on (c:Product) assert c.name is unique;

create constraint on (c:SubIssue) assert c.name is unique;

create constraint on (c:Issue) assert c.name is unique;

create constraint on (c:Company) assert c.name is unique;

create constraint on (c:Complaint) assert c.id is unique;

load csv with headers from "https://docs.google.com/spreadsheets/d/e/2PACX-1vTHPyjiQ1_nZuIkkRQj53RVEsHwWp_AsS8S06s6-qiUoXXfN0mCKXDOeSgt99voH6U8Kerc5vvtFQpm/pub?gid=1179076529&single=true&output=csv" as row return row limit 3;

load csv with headers from "https://docs.google.com/spreadsheets/d/e/2PACX-1vTHPyjiQ1_nZuIkkRQj53RVEsHwWp_AsS8S06s6-qiUoXXfN0mCKXDOeSgt99voH6U8Kerc5vvtFQpm/pub?gid=1179076529&single=true&output=csv" return row limit 3;

loads csv with headers from "https://docs.google.com/spreadsheets/d/e/2PACX-1vTHPyjiQ1_nZuIkkRQj53RVEsHwWp_AsS8S06s6-qiUoXXfN0mCKXDOeSgt99voH6U8Kerc5vvtFQpm/pub?gid=1179076529&single=true&output=csv" return row limit 3;

load csv with headers from "https://git.io/J1m7e" as row
return row limit 100;

load csv with headers from "https://git.io/J1m7e" as row
return row limit 5;

:guide intro