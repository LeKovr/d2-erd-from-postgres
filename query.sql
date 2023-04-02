with 
primary_keys as (
	select
	       kcu.table_name,
	       kcu.column_name
	from information_schema.table_constraints tco
	join information_schema.key_column_usage kcu 
	     on kcu.constraint_name = tco.constraint_name
	     and kcu.constraint_schema = tco.constraint_schema
	     and kcu.constraint_name = tco.constraint_name
	where tco.constraint_type = 'PRIMARY KEY'
	group by kcu.table_name, kcu.column_name
),
foreign_key_relationships as (
	SELECT
	    tc.table_name, 
	    kcu.column_name, 
	    ccu.table_name AS foreign_table_name,
	    ccu.column_name AS foreign_column_name 
	FROM 
	    information_schema.table_constraints AS tc 
	    JOIN information_schema.key_column_usage AS kcu
	      ON tc.constraint_name = kcu.constraint_name
	      AND tc.table_schema = kcu.table_schema
	    JOIN information_schema.constraint_column_usage AS ccu
	      ON ccu.constraint_name = tc.constraint_name
	      AND ccu.table_schema = tc.table_schema
	WHERE tc.constraint_type = 'FOREIGN KEY'
),
cols as (
	select pre_cols.*
	    , count(foreign_key_relationships.*) >= 1 as is_fk
	    , count(pk.*) >= 1 as is_pk
	from (
	    select cols_def.table_name
	    , CASE
	      WHEN data_type = 'USER-DEFINED' THEN
	        CASE WHEN udt_schema = 'pg_catalog' THEN '' ELSE udt_schema || '.' END || udt_name
	      WHEN data_type = 'ARRAY' THEN (
	        SELECT quote_ident(format_type(a.atttypid, a.atttypmod)) -- d2 needs quotes here
	          FROM pg_attribute a
	         WHERE a.attrelid = (cols_def.table_schema||'.'||cols_def.table_name)::regclass
	           AND attname=cols_def.column_name
	      )
	      ELSE data_type END as data_type
	    , is_nullable = 'YES' as is_nullable
	    , cols_def.column_name
	    , cols_def.ordinal_position
	    from information_schema.columns cols_def
	) pre_cols
	left join foreign_key_relationships
	  on pre_cols.table_name = foreign_key_relationships.table_name and pre_cols.column_name = foreign_key_relationships.column_name
	left join primary_keys pk
	  on pre_cols.table_name = pk.table_name and pre_cols.column_name = pk.column_name
	group by pre_cols.table_name, data_type, is_nullable, pre_cols.column_name, ordinal_position
)

SELECT information_schema.columns.table_name
, json_agg(cols.* order by cols.ordinal_position) as columns, json_agg(distinct foreign_key_relationships) AS foreign_relations
FROM information_schema.columns
left join foreign_key_relationships
  on foreign_key_relationships.table_name = information_schema.columns.table_name
left join cols
  on cols.table_name = information_schema.columns.table_name and cols.column_name = information_schema.columns.column_name
WHERE table_schema = $1
GROUP BY information_schema.columns.table_name


