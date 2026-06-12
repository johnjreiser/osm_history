explain
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
      WHEN sq.nodes[1] = sq.nodes[CARDINALITY(sq.nodes)] THEN st_makepolygon (ST_AddPoint (st_makeline (st_makepoint (sq.lon, sq.lat)), st_startpoint (st_makeline (st_makepoint (sq.lon, sq.lat)))))
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
      JOIN selected_records ON selected_records.id = w.id
      CROSS JOIN LATERAL UNNEST(w.nodes)
    WITH
      ORDINALITY AS u (node, node_order)
      LEFT JOIN LATERAL (
        SELECT
          id
        , TIMESTAMP
        , lon
        , lat
        , VERSION
        , ROW_NUMBER() OVER (
            PARTITION BY
              id
            ORDER BY
              VERSION DESC
          ) rn
        FROM
          osm_nodes -- order by u.node_order
        WHERE
          TIMESTAMP <= w.timestamp
      ) n ON n.id = u.node
      AND n.rn = 1
      -- and n.changeset = w.changeset 
    ORDER BY
      id
    , "version"
    , node_order
  ) sq
GROUP BY
  id
, "version"
, "timestamp"
, changeset
, username
, tags
, nodes;