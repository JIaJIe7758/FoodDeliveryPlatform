# Food Delivery Platform

## Description

A relational database developed using **PostgreSQL** to simulate a food delivery platform.

The project focuses on database design, data integrity, business rule implementation, and data retrieval and analysis using SQL and PL/pgSQL.

## Technologies

- PostgreSQL 13+
- SQL / PL/pgSQL
- DBeaver
- Git & GitHub

## Features

- **User Management:** Customers, drivers, and restaurant accounts.
- **Restaurant Management:** Restaurants and menu items.
- **Order Management:** Order creation, processing, and status tracking.
- **Delivery Management:** Driver assignments and location tracking.
- **Promotions:** Discount validation and application.
- **Reviews:** Customer feedback on orders.
- **Payment Methods:** Management of customer payment information.

## Database Structure

The database consists of **14 interconnected tables**, designed to ensure data consistency and referential integrity.

The implementation includes:

- Primary and foreign keys
- UNIQUE, NOT NULL, and CHECK constraints
- Functions and stored procedures
- Triggers for business rule validation
- Sample data for testing
- SQL queries for data retrieval and analysis

## Installation

1. Create a PostgreSQL database.
2. Execute `schema.sql` to create the tables, triggers and constraints.
3. Execute `procedures.sql` to implement functions.
4. Execute `data.sql` to insert sample data.
5. Execute `queries.sql` one by one to check it's output.

## Project Objectives

- Design and implement a relational database.
- Ensure data integrity through constraints and triggers.
- Automate database operations using PL/pgSQL.
- Apply SQL concepts to a realistic food delivery scenario.
