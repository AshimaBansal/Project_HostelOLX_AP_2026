-- ==============================================================================
-- HOSTEL OLX? / CAMPUS MARKETPLACE - RELATIONAL DATABASE SCHEMA (CP2)
-- Target RDBMS : PostgreSQL 15+
-- Architecture : Modular Campus Marketplace with Real-time Offers & Handover Safety
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- EXTENSIONS & UTILITIES
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Automatic timestamp updater function
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- 1. CAMPUS IDENTITY & PROFILES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(150) NOT NULL UNIQUE,
    full_name VARCHAR(120) NOT NULL,
    roll_number VARCHAR(30) UNIQUE,
    phone_number VARCHAR(20),
    hostel_block VARCHAR(50) NOT NULL,
    room_number VARCHAR(20) NOT NULL,
    program_of_study VARCHAR(80),
    graduation_year SMALLINT CHECK (graduation_year IS NULL OR graduation_year >= 2024),
    avatar_url TEXT,
    is_verified_student BOOLEAN NOT NULL DEFAULT TRUE,
    reputation_score NUMERIC(3,2) NOT NULL DEFAULT 5.00 CHECK (reputation_score BETWEEN 0.00 AND 5.00),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_rishihood_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]*\.)?rishihood\.edu\.in$')
);

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

-- ------------------------------------------------------------------------------
-- 2. CATEGORY TAXONOMY
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(80) NOT NULL UNIQUE,
    slug VARCHAR(80) NOT NULL UNIQUE,
    icon_name VARCHAR(50),
    description VARCHAR(255),
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 3. VERIFIED CAMPUS HANDOVER SPOTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS handover_spots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_name VARCHAR(120) NOT NULL UNIQUE,
    zone_code VARCHAR(40) NOT NULL,
    landmark_description TEXT NOT NULL,
    security_level VARCHAR(30) NOT NULL DEFAULT 'high_footfall' 
        CHECK (security_level IN ('cctv_monitored', 'guard_station', 'high_footfall', 'standard')),
    available_hours VARCHAR(80) NOT NULL DEFAULT '08:00 AM - 10:00 PM',
    latitude NUMERIC(9,6) CHECK (latitude IS NULL OR latitude BETWEEN -90.000000 AND 90.000000),
    longitude NUMERIC(9,6) CHECK (longitude IS NULL OR longitude BETWEEN -180.000000 AND 180.000000),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 4. MARKETPLACE LISTINGS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    preferred_spot_id UUID REFERENCES handover_spots(id) ON DELETE SET NULL,
    title VARCHAR(180) NOT NULL,
    description TEXT NOT NULL,
    price NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (price >= 0),
    original_purchase_price NUMERIC(10,2) CHECK (original_purchase_price IS NULL OR original_purchase_price >= price),
    is_negotiable BOOLEAN NOT NULL DEFAULT TRUE,
    listing_type VARCHAR(20) NOT NULL DEFAULT 'sale' 
        CHECK (listing_type IN ('sale', 'giveaway', 'exchange', 'urgent_sale')),
    item_condition VARCHAR(25) NOT NULL DEFAULT 'good' 
        CHECK (item_condition IN ('brand_new', 'like_new', 'good', 'fair', 'needs_repair')),
    status VARCHAR(20) NOT NULL DEFAULT 'active' 
        CHECK (status IN ('active', 'under_offer', 'reserved', 'sold', 'archived', 'delisted')),
    view_count INTEGER NOT NULL DEFAULT 0 CHECK (view_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_giveaway_zero_price CHECK (listing_type <> 'giveaway' OR price = 0)
);

CREATE TRIGGER trg_listings_updated_at
BEFORE UPDATE ON listings
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

-- ------------------------------------------------------------------------------
-- 5. LISTING IMAGES (PHOTO GALLERY)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS listing_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    is_cover BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 6. SAVED LISTINGS (WISHLIST)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS saved_listings (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    listing_id UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    personal_note VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, listing_id)
);

COMMIT;
