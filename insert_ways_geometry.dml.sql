-- explain (analyze, buffers, verbose, costs, timing)
with selected_records as ( -- select a subset of records
    select ow.id 
      from osm_ways ow
      left join ways_geometry wg on wg.id = ow.id 
     where ow.username = 'NJDataUploads'
       and ow.version = 1
       and wg.id is null -- only include osm_ways records where id not in ways_geometry
     limit 10
)
insert into ways_geometry 
select id
, "version"
, "timestamp"
, changeset
, username
, tags
, st_setsrid  (
    CASE
      WHEN sq.nodes[1] = sq.nodes[CARDINALITY(sq.nodes)] and cardinality(sq.nodes) >= 4 
      THEN st_makepolygon (ST_AddPoint (st_makeline (st_makepoint (sq.lon, sq.lat)), st_startpoint (st_makeline (st_makepoint (sq.lon, sq.lat)))))
      ELSE st_makeline (st_makepoint (sq.lon, sq.lat))
    END
  , 4326
  ) AS shape
FROM
  (
    SELECT
      w.id
    , w.version
    , w."timestamp"
    , w.changeset
    , w.username
    , w.tags
    , w.nodes
    , n.lon
    , n.lat
    FROM
      osm_ways w
      JOIN selected_records sr on w.id = sr.id 
      JOIN rel_way_node rwn on w.id = rwn.way_id and w.version = rwn.way_version 
      -- JOIN osm_nodes n ON n.id = rwn.node_id and n.TIMESTAMP <= w.timestamp
      LEFT JOIN LATERAL (
        SELECT DISTINCT ON (n.id)
          id
        , TIMESTAMP
        , lon
        , lat
        , VERSION
        FROM
          osm_nodes n
        WHERE
          n.id = rwn.node_id and 
          n.TIMESTAMP <= w.timestamp
        ORDER BY 
          n.id, n.version DESC 
      ) n ON TRUE -- filter is pushed inside lateral join
    ORDER BY
      w.id
    , w."version"
    , rwn.way_node_order
  ) sq
GROUP BY
  id
, "version"
, "timestamp"
, changeset
, username
, tags
, nodes;