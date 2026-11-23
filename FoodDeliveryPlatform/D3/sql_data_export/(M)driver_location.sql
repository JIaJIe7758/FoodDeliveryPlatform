SELECT COALESCE(jsonb_agg(doc ORDER BY location_id), '[]'::jsonb)::text AS mongo_json
FROM (
    SELECT dl.location_id,
           jsonb_build_object(
             '_id', jsonb_build_object('$numberInt', dl.location_id::text),
             'driver_account_id', jsonb_build_object('$numberInt', dl.driver_account_id::text),
             'location', jsonb_build_object(
                'type', 'Point',
                'coordinates', jsonb_build_array(
                    jsonb_build_object('$numberDouble', dl.longitude::text),
                    jsonb_build_object('$numberDouble', dl.latitude::text)
                )
             ),
             'location_time', jsonb_build_object('$date', to_char(dl.location_time, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))
           ) AS doc
    FROM driver_location dl
) AS x;