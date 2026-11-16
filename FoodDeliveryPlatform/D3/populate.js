
// =====================================================
// Online Food Delivery Platform - D3
// populate.js
// Populate MongoDB according to queries.js
// =====================================================

db = db.getSiblingDB("food_delivery");

// -----------------------------------------------------
// 1. CLEAN DATABASE
// -----------------------------------------------------

db.orders.drop();
db.restaurants.drop();
db.drivers.drop();
db.driver_locations.drop();

db.createCollection("orders");
db.createCollection("restaurants");
db.createCollection("drivers");
db.createCollection("driver_locations");

print("Collections created.");

// -----------------------------------------------------
// 2. RESTAURANTS
// -----------------------------------------------------

const foodTypes = [
    "Portuguese",
    "Italian",
    "Chinese",
    "Japanese",
    "American"
];

const menus = {
    Portuguese: ["Bacalhau", "Francesinha", "Bifana", "Caldo Verde", "Pastel de Nata"],
    Italian: ["Pizza", "Lasagna", "Carbonara", "Risotto", "Tiramisu"],
    Chinese: ["Fried Rice", "Dumplings", "Noodles", "Peking Duck", "Milk Tea"],
    Japanese: ["Sushi", "Ramen", "Tempura", "Udon", "Mochi"],
    American: ["Burger", "Hot Dog", "BBQ Ribs", "Chicken Wings", "Cheesecake"]
};

const categories = [
    "Main Course",
    "Main Course",
    "Main Course",
    "Main Course",
    "Dessert"
];

const cities = [
    { name: "Porto", latitude: 41.1579, longitude: -8.6291 },
    { name: "Setubal", latitude: 38.5244, longitude: -8.8882 },
    { name: "Coimbra", latitude: 40.2033, longitude: -8.4103 },
    { name: "Braga", latitude: 41.5454, longitude: -8.4265 },
    { name: "Lisbon", latitude: 38.7223, longitude: -9.1393 }
];

const restaurants = [];

for (let i = 1; i <= 20; i++) {

    const accountId = 250 + i;
    const foodTypeId = (accountId % 5) + 1;
    const foodType = foodTypes[foodTypeId - 1];
    const city = cities[accountId % 5];

    const menu = menus[foodType].map((dish, index) => {

        // Pizza and Lasagna at restaurant 1
        // are always available.
        let available = true;

        // Some dishes in other restaurants
        // are unavailable.
        if (i !== 1 && index === 3 && i % 2 === 0) {
            available = false;
        }

        return {
            menu_item_id: NumberInt((i - 1) * 5 + index + 1),
            name: dish,
            category: categories[index],
            price: NumberDecimal(
                (5 + ((i * 3 + index * 2) % 15) + 0.50).toFixed(2)
            ),
            is_available: available
        };
    });

    // Restaurant 1 must have Pizza, Lasagna and Tiramisu.
    // Tiramisu will deliberately never be ordered.

    restaurants.push({
        _id: NumberInt(i),
        restaurant_account_id: NumberInt(accountId),
        name: "Restaurant " + accountId,
        telephone: "925000" + String(accountId),
        street: "Street " + accountId,
        postal_code: "4000-" + String(i).padStart(3, "0"),
        city: city.name,

        location: {
            type: "Point",
            coordinates: [
                city.longitude,
                city.latitude
            ]
        },

        delivery_fee: NumberDecimal("2.50"),
        status: i % 5 === 0 ? "inactive" : "active",

        food_type: {
            food_type_id: NumberInt(foodTypeId),
            name: foodType
        },

        menu: menu
    });
}

db.restaurants.insertMany(restaurants);

print("Restaurants inserted: " + db.restaurants.countDocuments());

// -----------------------------------------------------
// 3. DRIVERS
// -----------------------------------------------------

const drivers = [];

for (let i = 208; i < 258; i++) {

    const index = i - 208;

    let availability;

    if (index % 3 === 0) {
        availability = "offline";
    } else if (index % 3 === 1) {
        availability = "available";
    } else {
        availability = "busy";
    }

    // Driver 208 must be available for query 13
    if (i === 208 || i === 209 || i === 210 || i === 211) {
        availability = "available";
    }

    const consent = i % 2 === 0;

    // Locations around Porto, with some drivers
    // closer to Restaurant 251.
    const longitude = -8.6291 + (index % 10) * 0.002;
    const latitude = 41.1579 + (index % 10) * 0.002;

    drivers.push({
        _id: NumberInt(i),
        full_name: "Driver " + i,
        telephone: "925000" + String(i),
        vehicle_type: i % 2 === 0 ? "motorcycle" : "bicycle",
        availability: availability,
        location_sharing_consent: consent,

        last_location: {
            point: {
                type: "Point",
                coordinates: [longitude, latitude]
            },
            recorded_at: new Date(Date.now() - index * 60000)
        }
    });
}

db.drivers.insertMany(drivers);

// Geospatial index for query 13
db.drivers.createIndex({
    "last_location.point": "2dsphere"
});

print("Drivers inserted: " + db.drivers.countDocuments());

// -----------------------------------------------------
// 4. ORDERS
// -----------------------------------------------------

const orders = [];

for (let i = 1; i <= 240; i++) {

    const restaurantId = ((i - 1) % 20) + 1;
    const restaurant = restaurants[restaurantId - 1];

    // Only the first four menu items can be ordered.
    // Dessert (Tiramisu at restaurant 1) is never ordered.
    const firstItemIndex = (i - 1) % 4;
    const secondItemIndex = (i + 1) % 4;

    const firstItem = restaurant.menu[firstItemIndex];
    const secondItem = restaurant.menu[secondItemIndex];

    const quantity1 = (i % 3) + 1;
    const quantity2 = i % 2 === 0 ? 1 : 0;

    const items = [
        {
            menu_item_id: firstItem.menu_item_id,
            name: firstItem.name,
            category: firstItem.category,
            quantity: quantity1,
            unit_price: firstItem.price
        }
    ];

    if (quantity2 > 0) {
        items.push({
            menu_item_id: secondItem.menu_item_id,
            name: secondItem.name,
            category: secondItem.category,
            quantity: quantity2,
            unit_price: secondItem.price
        });
    }

    // Calculate the total amount
    const itemsTotal =
        quantity1 * Number(firstItem.price.toString()) +
        quantity2 * Number(secondItem.price.toString());

    const deliveryFee = 2.50;

    const discount = i % 4 === 0 ? 1.50 : 0;

    const total = Number(
        (itemsTotal + deliveryFee - discount).toFixed(2)
    );

    // Order status distribution:
    // 1-200: delivered
    // 201-220: cancelled
    // 221-240: placed

    let status;

    if (i <= 200) {
        status = "delivered";
    } else if (i <= 220) {
        status = "cancelled";
    } else {
        status = "placed";
    }

    // Assign drivers to delivered orders.
    // First 10 orders belong to driver 208.
    // Next 10 belong to driver 209.
    // This guarantees at least 5 five-star ratings
    // for both drivers.

    let driverId = null;

    if (i <= 10) {
        driverId = 208;
    } else if (i <= 20) {
        driverId = 209;
    } else if (i <= 200) {
        driverId = 210 + ((i - 21) % 20);
    } else if (i <= 210) {
        driverId = 208 + ((i - 201) % 10);
    }

    const placedAt = new Date(
        Date.UTC(2026, 9, 1, 8, 0, 0) + i * 30 * 60000
    );

    const deliveredAt = status === "delivered"
        ? new Date(placedAt.getTime() + (20 + (i % 55)) * 60000)
        : null;

    const statusHistory = [
        { status: "placed", at: placedAt }
    ];

    if (status === "delivered") {
        statusHistory.push(
            { status: "accepted", at: new Date(placedAt.getTime() + 2 * 60000) },
            { status: "preparing", at: new Date(placedAt.getTime() + 5 * 60000) },
            { status: "delivering", at: new Date(placedAt.getTime() + 15 * 60000) },
            { status: "delivered", at: deliveredAt }
        );
    } else if (status === "cancelled") {
        statusHistory.push({
            status: "cancelled",
            at: new Date(placedAt.getTime() + 10 * 60000)
        });
    }

    const order = {
        _id: NumberInt(i),
        status: status,
        placed_at: placedAt,
        delivery_address: "Street " + i + ", Portugal",

        customer: {
            customer_account_id: NumberInt(1 + ((i - 1) % 40))
        },

        restaurant: {
            restaurant_id: restaurant._id,
            name: restaurant.name,
            city: restaurant.city,
            food_type: restaurant.food_type.name
        },

        payment: {
            payment_method_id: NumberInt(1 + ((i - 1) % 40)),
            status: status === "delivered" ? "paid" : "pending"
        },

        items: items,

        delivery_fee: NumberDecimal("2.50"),
        discount_amount: NumberDecimal(discount.toFixed(2)),
        total_amount: NumberDecimal(total.toFixed(2)),

        status_history: statusHistory
    };

    if (driverId !== null) {
        order.driver = {
            driver_account_id: NumberInt(driverId),
            full_name: "Driver " + driverId,
            vehicle_type: driverId % 2 === 0 ? "motorcycle" : "bicycle"
        };
    }

    if (status === "delivered") {

        order.delivered_at = deliveredAt;

        let restaurantRating;
        let driverRating;

        if (i <= 100) {
            restaurantRating = 5;
        } else if (i % 11 === 0) {
            restaurantRating = 1;
        } else if (i % 9 === 0) {
            restaurantRating = 2;
        } else {
            restaurantRating = 4;
        }

        if (i <= 20) {
            driverRating = 5;
        } else if (i % 10 === 0) {
            driverRating = 3;
        } else {
            driverRating = 4;
        }

        order.review = {
            review_id: NumberInt(i),
            restaurant_rating: NumberInt(restaurantRating),
            driver_rating: NumberInt(driverRating),
            comment: "Review for test order " + i,
            created_at: new Date(deliveredAt.getTime() + 60 * 60000)
        };
    }

    orders.push(order);
}

db.orders.insertMany(orders);

print("Orders inserted: " + db.orders.countDocuments());

// -----------------------------------------------------
// 5. DRIVER LOCATIONS (GPS HISTORY)
// -----------------------------------------------------

const gpsLocations = [];
let gpsId = 1;

for (let i = 208; i < 258; i++) {

    // Only drivers with location sharing consent
    // have GPS history.
    if (i % 2 === 0) {

        for (let j = 1; j <= 3; j++) {

            const index = i - 208;

            gpsLocations.push({
                _id: NumberInt(gpsId++),
                driver_account_id: NumberInt(i),

                location_time: new Date(
                    Date.now() - j * 10 * 60000
                ),

                location: {
                    type: "Point",
                    coordinates: [
                        -8.6291 + index * 0.001 + j * 0.0001,
                        41.1579 + index * 0.001 + j * 0.0001
                    ]
                }
            });
        }
    }
}

db.driver_locations.insertMany(gpsLocations);

print("GPS locations inserted: " + db.driver_locations.countDocuments());

// -----------------------------------------------------
// 6. FINAL VERIFICATION
// -----------------------------------------------------

print("");
print("========== POPULATION SUMMARY ==========");

print("Restaurants: " + db.restaurants.countDocuments());
print("Drivers: " + db.drivers.countDocuments());
print("Orders: " + db.orders.countDocuments());
print("GPS locations: " + db.driver_locations.countDocuments());

print("");
print("========== ORDER STATUS SUMMARY ==========");

printjson(
    db.orders.aggregate([
        {
            $group: {
                _id: "$status",
                total: { $sum: 1 }
            }
        },
        {
            $sort: { _id: 1 }
        }
    ]).toArray()
);

print("");
print("========== POPULATION COMPLETED ==========");

