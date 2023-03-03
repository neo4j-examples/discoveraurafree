MATCH path=(n:Tag)<--(p:Podcast)-->(m:Tag) 
WHERE id(n)>id(m)
RETURN n.name, m.name, count(*) as freq
order by freq desc 
LIMIT 10;

╒══════════════════════════╤══════════════════════╤══════╕
│"n.name"                  │"m.name"              │"freq"│
╞══════════════════════════╪══════════════════════╪══════╡
│"History"                 │"Society"             │322   │
├──────────────────────────┼──────────────────────┼──────┤
│"Society"                 │"Arts"                │241   │
├──────────────────────────┼──────────────────────┼──────┤
│"Self-Improvement"        │"Podcasting Education"│239   │
├──────────────────────────┼──────────────────────┼──────┤
│"Society"                 │"Podcasting Education"│227   │
├──────────────────────────┼──────────────────────┼──────┤
│"Business"                │"Podcasting Education"│211   │
├──────────────────────────┼──────────────────────┼──────┤
│"News"                    │"Society"             │203   │
├──────────────────────────┼──────────────────────┼──────┤
│"Binge-Worthy Documentary"│"Society"             │188   │
├──────────────────────────┼──────────────────────┼──────┤
│"Graphic Design"          │"Arts"                │185   │
├──────────────────────────┼──────────────────────┼──────┤
│"Storytelling"            │"True Crime"          │177   │
├──────────────────────────┼──────────────────────┼──────┤
│"Entrepreneur"            │"Business"            │176   │
└──────────────────────────┴──────────────────────┴──────┘

MATCH path=(n:Tag)-->(p:Podcast) RETURN path LIMIT 25;



:auto match (p:Podcast) 
call { with p
call apoc.load.json("https://player.fm/"+p.slug+".json") yield value
with p, value { .description, .language,.title,.id, .author, .home, episodes: value.stats.numberOfEpisodes } as data, [t IN value.tags | t {.title, .id} ] as tags
SET p += data
WITH *
call { with p, data
with * where not data.author is null
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
RETURN count(*)
} 
WITH *
UNWIND tags as tagData
MERGE (t:Tag {id:tagData.id}) SET t.name = tagData.title
MERGE (p)-[:TAGGED]->(t)
RETURN count(*) as count
} in transactions of 50 rows
return sum(count)

:auto match (p:Podcast) 
call { with p
call apoc.load.json("https://player.fm/"+p.slug+".json") yield value
with p, value { .description, .language,.title,.id, .author, .home, episodes: value.stats.numberOfEpisodes } as data, [t IN value.tags | t {.title, .id} ] as tags
SET p += data
call { with p, data
with * where not data.author is null
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
RETURN count(*)
} 
WITH *
UNWIND tags as tagData
MERGE (t:Tag {id:tagData.id}) SET t.name = tagData.title
MERGE (p)-[:TAGGED]->(t)
RETURN count(*) as count
} in transactions of 50 rows
return sum(count)

:auto match (p:Podcast) 
call { with p
call apoc.load.json("https://player.fm/"+p.slug+".json") yield value
with p, value { .description, .language,.title,.id, .author, .home, episodes: value.stats.numberOfEpisodes } as data, [t IN value.tags | t {.title, .id} ] as tags
SET p += data
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
WITH *
UNWIND tags as tagData
MERGE (t:Tag {id:tagData.id}) SET t.name = tagData.title
MERGE (p)-[:TAGGED]->(t)
RETURN count(*) as count
} in transactions of 50 rows
return sum(count)

:auto
match (p:Podcast) 
call { with p
call apoc.load.json("https://player.fm/"+p.slug+".json") yield value
with p, value { .description, .language,.title,.id, .author, .home, episodes: value.stats.numberOfEpisodes } as data, [t IN value.tags | t {.title, .id} ] as tags
SET p += data
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
WITH *
UNWIND tags as tagData
MERGE (t:Tag {id:tagData.id}) SET t.name = tagData.title
MERGE (p)-[:TAGGED]->(t)
RETURN count(*) as count
} in transactions of 50 rows
return sum(count)

:guide intro

match (p:Podcast) 
call apoc.load.json("https://player.fm/"+p.slug+".json") yield value
with p, value { .description, .language,.title,.id, .author, .home, episodes: value.stats.numberOfEpisodes } as data, [t IN value.tags | t {.title, .id} ] as tags
SET p += data
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
WITH *
UNWIND tags as tagData
MERGE (t:Tag {id:tagData.id}) SET t.name = tagData.title
MERGE (p)-[:TAGGED]->(t)
RETURN count(*);

:guide intro

:auto with "https://player.fm/series/99-invisible.json?detail=full&episode_detail=full&episode_offset=0&episode_order=newest&episode_limit=1000&at=1618384123&experiment_detail=full" as url
call apoc.load.json(url) yield value
with value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes } as data,
[ e IN value.episodes | e {title:e.minimalTitle, .duration, .id, .description,.slug, published: datetime({epochSeconds:e.publishedAt}) }] as episodes

MATCH (p:Podcast {id:data.id})
WITH distinct p, episodes
UNWIND episodes as epData
call {
    WITH epData, p
    MERGE (e:Episode {id:epData.id}) SET e += epData
    MERGE (e)<-[:PUBLISHED]-(p)
} in transactions of 20 rows
RETURN *

with "https://player.fm/series/99-invisible.json?detail=full&episode_detail=full&episode_offset=0&episode_order=newest&episode_limit=1000&at=1618384123&experiment_detail=full" as url
call apoc.load.json(url) yield value
with value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes } as data,
[ e IN value.episodes | e {title:e.minimalTitle, .duration, .id, .description,.slug, published: datetime({epochSeconds:e.publishedAt}) }] as episodes

MATCH (p:Podcast {id:data.id})
WITH distinct p, episodes
UNWIND episodes as epData
call {
    WITH epData, p
    MERGE (e:Episode {id:epData.id}) SET e += epData
    MERGE (e)<-[:PUBLISHED]-(p)
} in transactions of 20 rows
RETURN *;

with "https://player.fm/series/99-invisible.json?detail=full&episode_detail=full&episode_offset=0&episode_order=newest&episode_limit=1000&at=1618384123&experiment_detail=full" as url
call apoc.load.json(url) yield value
with value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes } as data, 
[t IN value.tags | t {.title, .id} ] as tags,
[ e IN value.episodes | e {title:e.minimalTitle, .duration, .id, .description,.slug, published: datetime({epochSeconds:e.publishedAt}) }] as episodes

MERGE (p:Podcast {id:data.id}) SET p += data
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
WITH *
UNWIND tags as tagData
MERGE (t:Tag {id:tagData.id}) SET t.name = tagData.title
MERGE (p)-[:TAGGED]->(t)
WITH distinct p, episodes
UNWIND episodes as epData

call {
    WITH epData, p
    MERGE (e:Episode {id:epData.id}) SET e += epData
    MERGE (e)<-[:PUBLISHED]-(p)
} in transactions of 20 rows
RETURN *;

create constraint on (h:Host) assert h.name is unique;

create constraint on (p:Podcast) assert p.id is unique;

create constraint on (e:Episode) assert e.id is unique;

create constraint on (t:Tag) assert t.name is unique;

create constraint (t:Tag) assert t.name is unique;

with "https://player.fm/series/99-invisible.json?detail=full&episode_detail=full&episode_offset=0&episode_order=newest&episode_limit=1000&at=1618384123&experiment_detail=full" as url
call apoc.load.json(url) yield value
with value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes } as data, 
[t IN value.tags | t {.title, .id} ] as tags,
[ e IN value.episodes | e {title:e.minimalTitle, .duration, .id, .description,.slug, published: datetime({epochSeconds:e.publishedAt}) }] as episodes

MERGE (p:Podcast {id:data.id}) SET p += data
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
WITH *
UNWIND tags as tagData
MERGE (t:Tag {id:tagData.id}) SET t.name = tagData.title
MERGE (p)-[:TAGGED]->(t)
WITH distinct p, episodes
UNWIND episodes as epData
MERGE (e:Episode {id:epData.id}) SET e += epData
MERGE (e)<-[:PUBLISHED]-(p)
RETURN *;

with "https://player.fm/series/99-invisible.json?detail=full&episode_detail=full&episode_offset=0&episode_order=newest&episode_limit=1000&at=1618384123&experiment_detail=full" as url
call apoc.load.json(url) yield value
return [ e IN value.episodes | e {title:e.minimalTitle, .duration, .id, .description,.slug, published: datetime({epochSeconds:e.publishedAt}) }] as episodes;

with "https://player.fm/series/99-invisible.json?detail=full&episode_detail=full&episode_offset=0&episode_order=newest&episode_limit=1000&at=1618384123&experiment_detail=full" as url
call apoc.load.json(url) yield value
return [ e IN value.episodes | e {title:e.minimalTitle, .duration, .id, .description,.slug, published: datetime({epochMillis:e.publishedAt}) }] as episodes;

with "https://player.fm/series/99-invisible.json?detail=full&episode_detail=full&episode_offset=0&episode_order=newest&episode_limit=1000&at=1618384123&experiment_detail=full" as url
call apoc.load.json(url) yield value
return [ e IN value.episodes | e {title:e.minimalTitle, .duration, .id, .description,.slug, published: datetime({epocMillis:e.publishedAt}) }] as episodes;

with "https://player.fm/series/99-invisible.json?detail=full&episode_detail=full&episode_offset=0&episode_order=newest&episode_limit=1000&at=1618384123&experiment_detail=full" as url
call apoc.load.json(url) yield value
return [ e IN value.episodes | e {title:e.minimalTitle, .duration, .id, .description,.slug, published: datetime({epochSeconds:e.publishedAt}) }] as episodes;

with "https://player.fm/series/99-invisible.json?detail=full&episode_detail=full&episode_offset=0&episode_order=newest&episode_limit=1000&at=1618384123&experiment_detail=full" as url
call apoc.load.json(url) yield value
return value.episodes | e {title:e.minimalTitle, .duration, .id, .description,.slug, published: datetime({epochSeconds:e.publishedAt}),  };

with "https://player.fm/series/99-invisible.json?detail=full&episode_detail=full&episode_offset=0&episode_order=newest&episode_limit=1000&at=1618384123&experiment_detail=full" as url
call apoc.load.json(url) yield value
return value;

with "https://player.fm/series/99-invisible.json?detail=full&episode_detail=full&episode_offset=0&episode_order=newest&episode_limit=1000&at=1618384123&experiment_detail=full" as url
call apoc.load.json(url) yield value
with value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes } as data, [t IN value.tags | t {.title, .id} ] as tags
MERGE (p:Podcast {id:data.id}) SET p += data
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
WITH *
UNWIND tags as tagData
MERGE (t:Tag {id:tagData.id}) SET t.name = tagData.title
MERGE (p)-[:TAGGED]->(t)
RETURN *;

call apoc.load.json("https://player.fm/series/99-invisible.json") yield value
with value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes } as data, [t IN value.tags | t {.title, .id} ] as tags
MERGE (p:Podcast {id:data.id}) SET p += data
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
WITH *
UNWIND tags as tagData
MERGE (t:Tag {id:tagData.id}) SET t.name = tagData.title
MERGE (p)-[:TAGGED]->(t)
RETURN *;

call apoc.load.json("https://player.fm/series/99-invisible.json") yield value
with value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes } as data, [t IN value.tags | t {.title, .id} ] as tags
MERGE (p:Podcast {id:data.id}) SET p += data
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
UNWIND tags as tagData
MERGE (t:Tag {id:tagData.id}) SET t.name = tagData.title
MERGE (p)-[:TAGGED]->(t)
RETURN *;

call apoc.load.json("https://player.fm/series/99-invisible.json") yield value
with value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes ] } as data, [t IN value.tags | t {.title, .id} ] as tags
MERGE (p:Podcast {id:data.id}) SET p += data
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
UNWIND tags as tagData
MERGE (t:Tag {id:tagData.id}) SET t.name = tagData.title
MERGE (p)-[:TAGGED]->(t)
RETURN *;

call apoc.load.json("https://player.fm/series/99-invisible.json") yield value
return [t IN value.tags | t {.title, .id} ];

call apoc.load.json("https://player.fm/series/99-invisible.json") yield value
return value.tags;

call apoc.load.json("https://player.fm/series/99-invisible.json");

call apoc.load.json("https://player.fm/series/99-invisible.json") yield value
with value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes } as data
MERGE (p:Podcast {id:data.id}) SET p += data
MERGE (h:Host {name:data.author})
MERGE (h)-[:HOSTS]->(p)
RETURN *;

call apoc.load.json("https://player.fm/series/99-invisible.json") yield value
with value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes } as data
MERGE (p:Podcast {id:data.id}) SET p += data
RETURN p;

call apoc.load.json("https://player.fm/series/99-invisible.json") yield value
with value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes } as data
MERGE (p:Podcast {id:data.id}) SET p += data;

call apoc.load.json("https://player.fm/series/99-invisible.json") yield value
return value { .description, .language,.title,.id, .slug, .author, .home, episodes: value.stats.numberOfEpisodes };

call apoc.load.json("https://player.fm/series/99-invisible.json");
