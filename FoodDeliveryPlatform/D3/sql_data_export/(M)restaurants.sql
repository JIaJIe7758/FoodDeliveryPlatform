SELECT COALESCE(jsonb_agg(doc ORDER BY restaurant_id), '[]'::jsonb)::text AS mongo_json
FROM (
    SELECT r.restaurant_id,
           jsonb_build_object(
              '_id', jsonb_build_object('$numberInt', r.restaurant_id::text),
              'restaurant_account_id', jsonb_build_object('$numberInt', r.restaurant_account_id::text),
              'name', r.name,
              'telephone', r.telephone,
              'street', r.street,
              'postal_code', trim(r.postal_code),
              'city', r.city,
              'location', jsonb_build_object(
                 'type', 'Point',
                 'coordinates', jsonb_build_array(
                    jsonb_build_object('$numberDouble', r.longitude::text),
                    jsonb_build_object('$numberDouble', r.latitude::text)
                 )
              ),
              'delivery_fee', jsonb_build_object('$numberDecimal', r.delivery_fee::text),
              'status', r.status,
              'food_type', jsonb_build_object(
                 'food_type_id', jsonb_build_object('$numberInt', ft.food_type_id::text),
                 'name', ft.name
              ),
              'menu', COALESCE(m.menu, '[]'::jsonb)
           ) AS doc
    FROM restaurant r
    JOIN food_type ft ON ft.food_type_id = r.food_type_id
    LEFT JOIN LATERAL (
        SELECT jsonb_agg(
             jsonb_build_object(
                 'menu_item_id', jsonb_build_object('$numberInt', mi.menu_item_id::text),
                 'name', mi.name,
                 'category', mi.category,
                 'price', jsonb_build_object('$numberDecimal', mi.price::text),
                 'is_available', mi.is_available
             ) ORDER BY mi.menu_item_id
        ) AS menu
        FROM menu_item mi
        WHERE mi.restaurant_id = r.restaurant_id
    ) m ON true
) AS x;
