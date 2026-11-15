// Selects the 'FoodDeliveryPlatform' database (equivalent to the 'use FoodDeliveryPlatform' command in the interactive mongosh shell).
// In JavaScript (.js) scripts, db.getSiblingDB() ensures that subsequent operations
// target the correct database regardless of which database was active when connecting.
db = db.getSiblingDB("FoodDeliveryPlatform");


// 1. Clean up existing collections (allows safe re-execution without duplicate key errors)
db.orders.drop();
db.restaurants.drop();
db.driver_locations.drop();

// 2. Create collection
db.createCollection("orders");
db.createCollection("restaurants");
db.createCollection("driver_locations");


//3.Validations

// 3.1. Configure orders validation
db.runCommand({
    collMod: "orders",
    validator: {
        $and: [
            {
                $jsonSchema: {
                    bsonType: "object",
                    required: [
                        "_id",
                        "customer_account_id",
                        "restaurant_id",
                        "payment_method_id",
                        "payment_status",
                        "total_amount",
                        "delivery_fee",
                        "delivery_address",
                        "status",
                        "placed_at",
                        "discount_amount",
                        "items"
                    ],
                    properties: {
                        _id: { bsonType: "int" },

                        customer_account_id: { bsonType: "int" },
                        restaurant_id: { bsonType: "int" },
                        driver_account_id: { bsonType: ["int", "null"] },
                        promotion_id: { bsonType: ["int", "null"] },
                        payment_method_id: { bsonType: "int" },

                        payment_status: {
                            enum: ["pending", "failed", "paid", "refunded"]
                        },

                        total_amount: {
                            bsonType: "decimal",
                            minimum: NumberDecimal("0")
                        },

                        delivery_fee: {
                            bsonType: "decimal",
                            minimum: NumberDecimal("0")
                        },

                        delivery_address: {
                            bsonType: "string",
                            maxLength: 255
                        },

                        status: {
                            enum: [
                                "placed",
                                "accepted",
                                "preparing",
                                "delivering",
                                "delivered",
                                "cancelled"
                            ]
                        },

                        placed_at: {
                            bsonType: "date"
                        },

                        delivered_at: {
                            bsonType: ["date", "null"]
                        },

                        discount_amount: {
                            bsonType: "decimal",
                            minimum: NumberDecimal("0")
                        },

                        //Embedded menu item
                        items: {
                            bsonType: "array",
                            items: {
                                bsonType: "object",
                                required: [
                                    "menu_item_id",
                                    "quantity",
                                    "unit_price"
                                ],
                                properties: {
                                    menu_item_id: {
                                        bsonType: "int"
                                    },

                                    quantity: {
                                        bsonType: "int",
                                        minimum: 1
                                    },

                                    unit_price: {
                                        bsonType: "decimal",
                                        minimum: NumberDecimal("0")
                                    }
                                }
                            }
                        },
                        //Embedded review
                        review: {
                            bsonType: ["object", "null"],
                            required: [
                                "review_id",
                                "restaurant_rating",
                                "created_at"
                            ],
                            properties: {
                                review_id: {
                                    bsonType: "int"
                                },

                                restaurant_rating: {
                                    bsonType: "int",
                                    minimum: 1,
                                    maximum: 5
                                },

                                driver_rating: {
                                    bsonType: ["int", "null"],
                                    minimum: 1,
                                    maximum: 5
                                },

                                comment: {
                                    bsonType: ["string", "null"],
                                    maxLength: 500
                                },

                                created_at: {
                                    bsonType: "date"
                                }
                            }
                        }
                    }
                }
            },

            // SQL CHECK:
            // NOT (status = 'delivered' AND delivered_at IS NULL)
            {
                $or: [
                    { status: { $ne: "delivered" } },
                    { delivered_at: { $type: "date" } }
                ]
            }
        ]
    },

    validationLevel: "strict",
    validationAction: "error"
});


// 3.2. Configure restaurants validation
db.runCommand({
    collMod: "restaurants",
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: [
                "_id",
                "restaurant_account_id",
                "name",
                "telephone",
                "street",
                "postal_code",
                "city",
                "location",
                "delivery_fee",
                "status",
                "food_type",
                "menu_items"
            ],
            properties: {
                _id: {
                    bsonType: "int"
                },

                restaurant_account_id: {
                    bsonType: "int"
                },

                name: {
                    bsonType: "string",
                    maxLength: 100
                },

                telephone: {
                    bsonType: "string",
                    maxLength: 20
                },

                street: {
                    bsonType: "string",
                    maxLength: 150
                },

                postal_code: {
                    bsonType: "string",
                    pattern: "^[0-9]{4}-[0-9]{3}$"
                },

                city: {
                    bsonType: "string",
                    maxLength: 60
                },

                // GeoJSON Point: [longitude, latitude]
                location: {
                    bsonType: "object",
                    required: ["type", "coordinates"],
                    properties: {
                        type: {
                            enum: ["Point"]
                        },

                        coordinates: {
                            bsonType: "array",
                            minItems: 2,
                            maxItems: 2,
                            items: {
                                bsonType: "double"
                            }
                        }
                    }
                },

                delivery_fee: {
                    bsonType: "decimal",
                    minimum: NumberDecimal("0"),
                },

                status: {
                    enum: ["active", "inactive"]
                },

                // Embedded food_type
                food_type: {
                    bsonType: "object",
                    required: [
                        "food_type_id",
                        "name"
                    ],
                    properties: {
                        food_type_id: {
                            bsonType: "int"
                        },

                        name: {
                            bsonType: "string",
                            maxLength: 50
                        }
                    }
                },

                // Embedded menu_item records
                menu_items: {
                    bsonType: "array",
                    items: {
                        bsonType: "object",
                        required: [
                            "menu_item_id",
                            "name",
                            "category",
                            "price",
                            "is_available"
                        ],
                        properties: {
                            menu_item_id: {
                                bsonType: "int"
                            },

                            name: {
                                bsonType: "string",
                                maxLength: 100
                            },

                            category: {
                                bsonType: "string",
                                maxLength: 50
                            },

                            price: {
                                bsonType: "decimal",
                                minimum: NumberDecimal("0"),
                            },

                            is_available: {
                                bsonType: "bool"
                            }
                        }
                    }
                }
            }
        }
    },

    validationLevel: "strict",
    validationAction: "error"
});

// 3.3. Configure driver_locations validation
db.runCommand({
    collMod: "driver_locations",
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: [
                "_id",
                "driver_account_id",
                "location",
                "location_time"
            ],
            properties: {
                _id: {
                    bsonType: "int"
                },

                driver_account_id: {
                    bsonType: "int"
                },

                // GeoJSON Point: [longitude, latitude]
                location: {
                    bsonType: "object",
                    required: [
                        "type",
                        "coordinates"
                    ],
                    properties: {
                        type: {
                            enum: ["Point"]
                        },

                        coordinates: {
                            bsonType: "array",
                            minItems: 2,
                            maxItems: 2,
                            items: {
                                bsonType: "double"
                            }
                        }
                    }
                },

                location_time: {
                    bsonType: "date"
                }
            }
        }
    },

    validationLevel: "strict",
    validationAction: "error"
});


