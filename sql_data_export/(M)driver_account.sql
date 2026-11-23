SELECT
    driver_account_id AS _id,
    full_name,
    telephone,
    vehicle_type,
    availability,
    location_sharing_consent
FROM driver_account
ORDER BY driver_account_id;

