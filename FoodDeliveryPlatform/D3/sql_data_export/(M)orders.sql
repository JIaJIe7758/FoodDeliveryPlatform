SELECT COALESCE(jsonb_agg(doc ORDER BY order_id), '[]'::jsonb)::text AS mongo_json
FROM (
    SELECT o.order_id,
           jsonb_build_object(
              '_id', jsonb_build_object('$numberInt', o.order_id::text),
              'customer', jsonb_build_object(
                  'customer_account_id', jsonb_build_object('$numberInt', o.customer_account_id::text)
              ),
              'restaurant', jsonb_build_object(
                  'restaurant_id', jsonb_build_object('$numberInt', r.restaurant_id::text),
                  'name', r.name,
                  'city', r.city,
                  'food_type', ft.name
              ),
              'payment', jsonb_build_object(
                  'payment_method_id', jsonb_build_object('$numberInt', o.payment_method_id::text),
                  'status', o.payment_status
              ),
              'driver', CASE WHEN d.driver_account_id IS NULL THEN 'null'::jsonb ELSE
                  jsonb_build_object(
                      'driver_account_id', jsonb_build_object('$numberInt', d.driver_account_id::text),
                      'full_name', d.full_name,
                      'vehicle_type', d.vehicle_type
                  ) END,
              'promotion_id', CASE WHEN o.promotion_id IS NULL THEN 'null'::jsonb ELSE
                  jsonb_build_object('$numberInt', o.promotion_id::text) END,
              'total_amount', jsonb_build_object('$numberDecimal', o.total_amount::text),
              'delivery_fee', jsonb_build_object('$numberDecimal', o.delivery_fee::text),
              'delivery_address', o.delivery_address,
              'status', o.status,
              'placed_at', jsonb_build_object('$date', to_char(o.placed_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')),
              'delivered_at', CASE WHEN o.delivered_at IS NULL THEN 'null'::jsonb ELSE
                  jsonb_build_object('$date', to_char(o.delivered_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')) END,
              'discount_amount', jsonb_build_object('$numberDecimal', o.discount_amount::text),
              'items', COALESCE(it.items, '[]'::jsonb),
              'review', CASE WHEN rv.review_id IS NULL THEN 'null'::jsonb ELSE
                  jsonb_build_object(
                      'review_id', jsonb_build_object('$numberInt', rv.review_id::text),
                      'restaurant_rating', jsonb_build_object('$numberInt', rv.restaurant_rating::text),
                      'driver_rating', CASE WHEN rv.driver_rating IS NULL THEN 'null'::jsonb ELSE
                          jsonb_build_object('$numberInt', rv.driver_rating::text) END,
                      'comment', rv.comment,
                      'created_at', jsonb_build_object('$date', to_char(rv.created_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))
                  ) END,
              'status_history', '[]'::jsonb
           ) AS doc
    FROM customer_order o
    JOIN restaurant r ON r.restaurant_id = o.restaurant_id
    JOIN food_type ft ON ft.food_type_id = r.food_type_id
    LEFT JOIN driver_account d ON d.driver_account_id = o.driver_account_id
    LEFT JOIN review rv ON rv.order_id = o.order_id
    LEFT JOIN LATERAL (
        SELECT jsonb_agg(
            jsonb_build_object(
                'menu_item_id', jsonb_build_object('$numberInt', oi.menu_item_id::text),
                'name', mi.name,
                'category', mi.category,
                'quantity', jsonb_build_object('$numberInt', oi.quantity::text),
                'unit_price', jsonb_build_object('$numberDecimal', oi.unit_price::text)
            ) ORDER BY oi.menu_item_id
        ) AS items
        FROM order_item oi
        JOIN menu_item mi ON mi.menu_item_id = oi.menu_item_id
        WHERE oi.order_id = o.order_id
    ) it ON true
) AS x;
