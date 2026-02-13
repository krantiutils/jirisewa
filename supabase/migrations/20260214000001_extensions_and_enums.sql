-- Enable PostGIS for geography/geometry types and spatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- Application enums

CREATE TYPE app_role AS ENUM ('farmer', 'consumer', 'rider');

CREATE TYPE vehicle_type AS ENUM ('bike', 'car', 'truck', 'bus', 'other');

CREATE TYPE trip_status AS ENUM ('scheduled', 'in_transit', 'completed', 'cancelled');

CREATE TYPE order_status AS ENUM (
    'pending', 'matched', 'picked_up', 'in_transit',
    'delivered', 'cancelled', 'disputed'
);

CREATE TYPE payment_method AS ENUM ('cash', 'esewa', 'khalti');

CREATE TYPE payment_status AS ENUM ('pending', 'collected', 'settled');

CREATE TYPE app_language AS ENUM ('en', 'ne');

CREATE TYPE role_rated AS ENUM ('farmer', 'consumer', 'rider');
