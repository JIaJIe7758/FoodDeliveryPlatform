//Online Food Delivery Platform- D3
// queries.js - CRUD operations and aggregation pipelines

//Order to run: After the migration and after the consistency tests, because the CREATE, UPDATE and DELETE parts change the data.

//How to run: open MongoDB Compass, open the shell at the bottom (>_ MONGOSH) and copy and paste the queries.

//The collections that we use:
// orders -> order + embedded items + embedded review + status_history
// restaurants -> restaurant + food_type + embedded menu
// drivers -> driver profile + availability + last_location
// driver_locations -> time-series collection with every GPS point

//Choosing our database where our queries will run
use food_delivery;


//CREATE operations

//1. A customer places an order with 2 items (1 Pizza and 2 Lasagnas from restaurant 1).
//The prices in our data are random (data.sql uses RANDOM()), so we do not write them by hand:
// We copy them from the menu at the time of the purchase, as the requirements say. This way the order always matches the menu.
// First we find the dishes

const pizza = db.restaurants.findOne(
    { _id: 1, menu: { $elemMatch: { name: "Pizza", is_available: true } } },
    { "menu.$": 1, delivery_fee: 1, name: 1, city: 1, food_type: 1 }
);

const lasagna = db.restaurants.findOne(
    { _id: 1, menu: { $elemMatch: { name: "Lasagna", is_available: true } } },
    { "menu.$": 1 }
);

// Check that both dishes exist
if (!pizza || !lasagna) {
    throw new Error("Pizza or Lasagna not available in restaurant 1");
}

// Prices for calculation
const pizzaPrice = Number(pizza.menu[0].price);
const lasagnaPrice = Number(lasagna.menu[0].price);
const deliveryFee = Number(pizza.delivery_fee);

// Calculate total
const total = Math.round(
    (pizzaPrice + 2 * lasagnaPrice + deliveryFee) * 100
) / 100;

// Insert order
db.orders.insertOne({
    _id: 5001,
    status: "placed",
    placed_at: new Date(),
    delivery_address: "Street 1, 1000-001 Porto",

    customer: {
        customer_account_id: 1
    },

    restaurant: {
        restaurant_id: 1,
        name: pizza.name,
        city: pizza.city,
        food_type: pizza.food_type.name
    },

    payment: {
        payment_method_id: 1,
        status: "pending"
    },

    items: [
        {
            menu_item_id: pizza.menu[0].menu_item_id,
            name: pizza.menu[0].name,
            category: pizza.menu[0].category,
            quantity: 1,
            unit_price: pizza.menu[0].price
        },
        {
            menu_item_id: lasagna.menu[0].menu_item_id,
            name: lasagna.menu[0].name,
            category: lasagna.menu[0].category,
            quantity: 2,
            unit_price: lasagna.menu[0].price
        }
    ],

    delivery_fee: pizza.delivery_fee,
    discount_amount: NumberDecimal("0"),
    total_amount: NumberDecimal(total.toFixed(2)),

    status_history: [
        {
            status: "placed",
            at: new Date()
        }
    ]
});

db.orders.findOne({ _id: 5001 }); // shows the new order

//2. New GPS point of driver 208, who is online and shares the location.
//The point is inserted in the time-series collection , and the driver's last position is updated,
// so the customer can see it without having to read the whole history.
db.driver_locations.insertOne({
  driver_account_id: 208,
  location_time: new Date(),
  location: { type: "Point", coordinates: [-9.1340, 38.7160] }     // [longitude, latitude]
});

db.drivers.updateOne(
  { _id: 208 },
  { $set: { last_location: { point: { type: "Point", coordinates: [-9.1340, 38.7160] },
                             recorded_at: new Date() } } }
);


//READ operations
//3. Top 10 drivers having in consideration the number of delivered orders and average driver rating.
db.orders.aggregate([
  { $match: { status: "delivered" } },
  { $group: {
      _id: "$driver.full_name",
      delivered_orders:  { $sum: 1 },
      avg_driver_rating: { $avg: "$review.driver_rating" }
  }},
  { $sort: { delivered_orders: -1 } },
  { $limit: 10 }
]);

//4. Revenue and number of completed orders per restaurant.
db.orders.aggregate([
  { $match: { status: "delivered" } },
  { $group: {
      _id: "$restaurant.name",
      completed_orders: { $sum: 1 },
      revenue:          { $sum: "$total_amount" }
  }},
  { $sort: { revenue: -1 } }
]);

//5. Top 10 best-selling dishes and their food type.
//$unwind creates one document per item of each order, so that the quantities can be added.
// The _id has two fields (dish and food type)
db.orders.aggregate([
  { $match: { status: "delivered" } },
  { $unwind: "$items" },
  { $group: {
      _id: { dish: "$items.name", food_type: "$restaurant.food_type" },
      units_sold: { $sum: "$items.quantity" }
  }},
  { $sort: { units_sold: -1 } },
  { $limit: 10 }
]);

//6. Average delivery time per restaurant, slowest first
//$project calculates the dleivery time of each order before grouping.
//delivered_at - placed_at gives miliseconds, so /60000 gives minutes.
db.orders.aggregate([
  { $match: { status: "delivered" } },
  { $project: {
      restaurant: "$restaurant.name",
      delivery_minutes: { $divide: [ { $subtract: ["$delivered_at", "$placed_at"] }, 60000 ] }
  }},
  { $group: {
      _id: "$restaurant",
      avg_delivery_minutes: { $avg: "$delivery_minutes" }
  }},
  { $sort: { avg_delivery_minutes: -1 } }
]);

//7. Available dishes that were never ordered.
//The menu is inside restaurants and the sold items are inside orders.
//So, we basically $unwind the menu, $lookup the orders that contain each dish, and keep the dishes 
//where the lookup found nothing.
db.restaurants.aggregate([
  { $unwind: "$menu" },
  { $match: { "menu.is_available": true } },
  { $lookup: {
      from: "orders",
      localField: "menu.menu_item_id",
      foreignField: "items.menu_item_id",
      as: "orders_with_dish"
  }},
  { $match: { orders_with_dish: [] } },
  { $project: { _id: 0, restaurant: "$name", dish: "$menu.name", price: "$menu.price" } }
]);

//8. Restaurants with the most negative reviews (1 or 2 stars).
// $push keeps the comments of those reviews in a list.
db.orders.aggregate([
  { $match: { "review.restaurant_rating": { $lte: 2 } } },
  { $group: {
      _id: "$restaurant.name",
      negative_reviews: { $sum: 1 },
      comments:         { $push: "$review.comment" }
  }},
  { $sort: { negative_reviews: -1 } }
]);

//9. Drivers with at least 5 five-star ratings on delivered orders.
db.orders.aggregate([
  { $match: { status: "delivered", "review.driver_rating": 5 } },
  { $group: {
      _id: "$driver.full_name",
      five_star_deliveries: { $sum: 1 }
  }},
  { $match: { five_star_deliveries: { $gte: 5 } } },
  { $sort: { five_star_deliveries: -1 } }
]);

//10. Revenue lost to cancellations and at what stage.
//A cancelled order without a driver was cancelled before a driver was assigned.
//$cond is like CASE WHEN in SQL
db.orders.aggregate([
  { $match: { status: "cancelled" } },
  { $group: {
      _id: { $cond: [ "$driver", "After driver assigned", "Before driver assigned" ] },
      cancelled_orders: { $sum: 1 },
      lost_revenue:     { $sum: "$total_amount" }
  }}
]);

//11. For each driver we want how many GPS points were recorded, and the time of the first and last point.
//It uses the time-series collection driver_locations.
//The GPS points only have the driver's id, so $lookup gets the driver's name from the drivers collection.
db.driver_locations.aggregate([
  { $group: {
      _id: "$driver_account_id",
      gps_points: { $sum: 1 },
      first_time: { $min: "$location_time" },
      last_time:  { $max: "$location_time" }
  }},
  { $lookup: {
      from: "drivers",
      localField: "_id",
      foreignField: "_id",
      as: "driver"
  }},
  { $unwind: "$driver" },
  { $project: { _id: 0, driver: "$driver.full_name", gps_points: 1, first_time: 1, last_time: 1 } },
  { $sort: { gps_points: -1 } }
]);

//12. Latest position of the drivers that are online and share their location.
//It reads the last_location kept in each driver document, so it does not need to go through the whole GPS history.
db.drivers.aggregate([
  { $match: { availability: { $ne: "offline" }, location_sharing_consent: true } },
  { $project: { _id: 0, full_name: 1, availability: 1,
                coordinates: "$last_location.point.coordinates",
                recorded_at: "$last_location.recorded_at" } },
  { $sort: { recorded_at: -1 } }
]);

//13. The 3 available drivers closest to Restaurant 251.
//The 2dsphere index allows geospatial queries on the GeoJSON points.
//$nearSphere returns the documents sorted from the closest to the farthest.
db.drivers.createIndex({ "last_location.point": "2dsphere" });

db.drivers.find(
  { availability: "available",
    "last_location.point": {
      $nearSphere: { $geometry: { type: "Point", coordinates: [-8.6291, 41.1579] } }
    } },
  { _id: 0, full_name: 1, vehicle_type: 1 }
).limit(3);


//UPDATE operations
//14. The restaurant accepts order 5001.
// $set changes the status and $push adds the change to the history.
// the order of events is: placed -> accepted -> preparing -> delivering -> delivered.
db.orders.updateOne(
  { _id: 5001, status: "placed" },
  { $set:  { status: "accepted", "payment.status": "paid" },
    $push: { status_history: { status: "accepted", at: new Date() } } }
);

//15. Driver 208, who is available, takes the order.
//The driver is only assigned after the restaurant accepted the order.
db.drivers.updateOne(
  { _id: 208, availability: "available" },
  { $set: { availability: "busy" } }
);

db.orders.updateOne(
  { _id: 5001, status: "accepted" },
  { $set: { driver: { driver_account_id: 208, full_name: "Driver 208", vehicle_type: "motorcycle" } } }
);

//16. The order goes through the next statuses until it is delivered.
//Each update only works if the order is in the previous status.
db.orders.updateOne(
  { _id: 5001, status: "accepted" },
  { $set:  { status: "preparing" },
    $push: { status_history: { status: "preparing", at: new Date() } } }
);

db.orders.updateOne(
  { _id: 5001, status: "preparing" },
  { $set:  { status: "delivering" },
    $push: { status_history: { status: "delivering", at: new Date() } } }
);

db.orders.updateOne(
  { _id: 5001, status: "delivering" },
  { $set:  { status: "delivered", delivered_at: new Date() },
    $push: { status_history: { status: "delivered", at: new Date() } } }
);

//The driver is again available
db.drivers.updateOne(                        
  { _id: 208 },
  { $set: { availability: "available" } }
);

//17. The customer reviews the delivered order
//The filter of the status to "delivered" makes sure only delivered orders can be reviewed.
db.orders.updateOne(
  { _id: 5001, status: "delivered" },
  { $set: { review: { review_id: 5001, restaurant_rating: 5, driver_rating: 4,
                      comment: "Very good!", created_at: new Date() } } }
);


//DELETE operations
//18. Restaurant 251 removes the Tiramisu from its menu.
db.restaurants.updateOne(
  { _id: 1 },
  { $pull: { menu: { name: "Tiramisu" } } }
);

//19. Driver 208 removes the consent to share the location.
db.drivers.updateOne(
  { _id: 208 },
  { $set: { location_sharing_consent: false, last_location: null } }
);

db.driver_locations.deleteMany({ driver_account_id: 208 });


