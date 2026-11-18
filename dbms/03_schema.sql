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

-- ------------------------------------------------------------------------------
-- 7. OLX PRICE BARGAINING & OFFERS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS price_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    buyer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    offered_amount NUMERIC(10,2) NOT NULL CHECK (offered_amount > 0),
    counter_amount NUMERIC(10,2) CHECK (counter_amount IS NULL OR counter_amount > 0),
    buyer_note VARCHAR(255),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'accepted', 'countered', 'declined', 'withdrawn', 'expired')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_price_offers_updated_at
BEFORE UPDATE ON price_offers
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

-- ------------------------------------------------------------------------------
-- 8. PHYSICAL HANDOVER TRANSACTIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS handover_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES listings(id) ON DELETE RESTRICT,
    buyer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    seller_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    accepted_offer_id UUID REFERENCES price_offers(id) ON DELETE SET NULL,
    spot_id UUID NOT NULL REFERENCES handover_spots(id) ON DELETE RESTRICT,
    final_agreed_price NUMERIC(10,2) NOT NULL CHECK (final_agreed_price >= 0),
    payment_method VARCHAR(25) NOT NULL DEFAULT 'upi_on_spot' 
        CHECK (payment_method IN ('upi_on_spot', 'cash_in_hand', 'free_giveaway')),
    verification_pin VARCHAR(6) NOT NULL,
    scheduled_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled' 
        CHECK (status IN ('scheduled', 'arrived', 'completed', 'cancelled', 'disputed')),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_tx_buyer_seller_distinct CHECK (buyer_id <> seller_id),
    CONSTRAINT chk_tx_completed_time CHECK (completed_at IS NULL OR completed_at >= created_at)
);

CREATE TRIGGER trg_transactions_updated_at
BEFORE UPDATE ON handover_transactions
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

-- ------------------------------------------------------------------------------
-- 9. PEER REVIEWS & REPUTATION
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS peer_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES handover_transactions(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reviewee_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    rating_stars SMALLINT NOT NULL CHECK (rating_stars BETWEEN 1 AND 5),
    review_comment TEXT,
    punctuality_rating SMALLINT CHECK (punctuality_rating BETWEEN 1 AND 5),
    item_accuracy_rating SMALLINT CHECK (item_accuracy_rating BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_transaction_reviewer UNIQUE (transaction_id, reviewer_id),
    CONSTRAINT chk_review_parties_distinct CHECK (reviewer_id <> reviewee_id)
);

-- ------------------------------------------------------------------------------
-- 10. REAL-TIME CHAT CHANNELS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_channels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    buyer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_channel_listing_buyer_seller UNIQUE (listing_id, buyer_id, seller_id),
    CONSTRAINT chk_channel_parties_distinct CHECK (buyer_id <> seller_id)
);

-- ------------------------------------------------------------------------------
-- 11. CHAT MESSAGES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES chat_channels(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    message_body TEXT NOT NULL CHECK (length(trim(message_body)) > 0),
    message_type VARCHAR(20) NOT NULL DEFAULT 'text' 
        CHECK (message_type IN ('text', 'image_url', 'offer_event', 'location_share', 'system_event')),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 12. LOST & FOUND INCIDENT REPORTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS lost_found_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    report_type VARCHAR(10) NOT NULL CHECK (report_type IN ('lost', 'found')),
    item_name VARCHAR(160) NOT NULL,
    description TEXT NOT NULL,
    last_seen_location VARCHAR(200) NOT NULL,
    event_date DATE NOT NULL,
    image_url TEXT,
    custody_location VARCHAR(120),
    status VARCHAR(20) NOT NULL DEFAULT 'open' 
        CHECK (status IN ('open', 'claim_pending', 'resolved', 'closed_unresolved')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_lost_found_updated_at
BEFORE UPDATE ON lost_found_reports
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

-- ------------------------------------------------------------------------------
-- 13. LOST & FOUND CLAIM REQUESTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claim_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES lost_found_reports(id) ON DELETE CASCADE,
    claimant_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    proof_description TEXT NOT NULL,
    identifying_features TEXT,
    contact_phone VARCHAR(20),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'under_verification', 'approved', 'rejected', 'withdrawn')),
    resolution_remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_report_claimant UNIQUE (report_id, claimant_id)
);

CREATE TRIGGER trg_claim_requests_updated_at
BEFORE UPDATE ON claim_requests
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

-- ------------------------------------------------------------------------------
-- 14. CAMPUS SAFETY & MODERATION REPORTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS safety_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    reported_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    reported_listing_id UUID REFERENCES listings(id) ON DELETE SET NULL,
    violation_category VARCHAR(35) NOT NULL 
        CHECK (violation_category IN ('counterfeit', 'harassment', 'scam_pricing', 'prohibited_goods', 'no_show_flake', 'other')),
    report_details TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'investigating', 'resolved_action_taken', 'dismissed')),
    admin_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,
    CONSTRAINT chk_safety_target_exists CHECK (reported_user_id IS NOT NULL OR reported_listing_id IS NOT NULL)
);

-- ==============================================================================
-- INDEXING STRATEGY (QUERY WORKLOAD OPTIMIZATION)
-- ==============================================================================

-- 1. Foreign Key Lookups
CREATE INDEX IF NOT EXISTS idx_listings_seller ON listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_category ON listings(category_id);
CREATE INDEX IF NOT EXISTS idx_listings_preferred_spot ON listings(preferred_spot_id);
CREATE INDEX IF NOT EXISTS idx_listing_images_listing ON listing_images(listing_id);
CREATE INDEX IF NOT EXISTS idx_saved_listings_listing ON saved_listings(listing_id);
CREATE INDEX IF NOT EXISTS idx_price_offers_listing ON price_offers(listing_id);
CREATE INDEX IF NOT EXISTS idx_price_offers_buyer ON price_offers(buyer_id);
CREATE INDEX IF NOT EXISTS idx_handover_tx_listing ON handover_transactions(listing_id);
CREATE INDEX IF NOT EXISTS idx_handover_tx_buyer ON handover_transactions(buyer_id);
CREATE INDEX IF NOT EXISTS idx_handover_tx_seller ON handover_transactions(seller_id);
CREATE INDEX IF NOT EXISTS idx_handover_tx_spot ON handover_transactions(spot_id);
CREATE INDEX IF NOT EXISTS idx_peer_reviews_reviewee ON peer_reviews(reviewee_id);
CREATE INDEX IF NOT EXISTS idx_chat_channels_buyer ON chat_channels(buyer_id);
CREATE INDEX IF NOT EXISTS idx_chat_channels_seller ON chat_channels(seller_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_channel ON chat_messages(channel_id, sent_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_lost_found_reporter ON lost_found_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_lost_found_category ON lost_found_reports(category_id);
CREATE INDEX IF NOT EXISTS idx_claim_requests_claimant ON claim_requests(claimant_id);
CREATE INDEX IF NOT EXISTS idx_safety_reports_reporter ON safety_reports(reporter_id);

-- 2. Feed Sorting & Active Status Partial Indexes
CREATE INDEX IF NOT EXISTS idx_listings_active_recent 
    ON listings(created_at DESC) WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_listings_category_price 
    ON listings(category_id, price ASC) WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_lost_found_open_recent 
    ON lost_found_reports(event_date DESC) WHERE status = 'open';

CREATE INDEX IF NOT EXISTS idx_chat_messages_unread 
    ON chat_messages(channel_id) WHERE is_read = FALSE;

-- ==============================================================================
-- ANALYTICAL VIEWS
-- ==============================================================================

-- Active marketplace catalog with cover photo, category name, and spot name
CREATE OR REPLACE VIEW vw_active_marketplace_catalog AS
SELECT 
    l.id AS listing_id,
    l.title,
    l.description,
    l.price,
    l.original_purchase_price,
    l.is_negotiable,
    l.listing_type,
    l.item_condition,
    l.created_at AS listed_at,
    c.name AS category_name,
    c.slug AS category_slug,
    u.id AS seller_id,
    u.full_name AS seller_name,
    u.hostel_block AS seller_hostel,
    u.reputation_score AS seller_reputation,
    hs.spot_name AS preferred_handover_spot,
    hs.landmark_description AS spot_landmark,
    (SELECT img.image_url FROM listing_images img 
     WHERE img.listing_id = l.id 
     ORDER BY img.is_cover DESC, img.display_order ASC LIMIT 1) AS primary_image_url
FROM listings l
JOIN categories c ON l.category_id = c.id
JOIN users u ON l.seller_id = u.id
LEFT JOIN handover_spots hs ON l.preferred_spot_id = hs.id
WHERE l.status = 'active';

-- Campus user reputation and trust summary
CREATE OR REPLACE VIEW vw_user_reputation_summary AS
SELECT 
    u.id AS user_id,
    u.full_name,
    u.hostel_block,
    u.reputation_score,
    COUNT(DISTINCT pr.id) AS total_reviews_received,
    COALESCE(ROUND(AVG(pr.rating_stars)::numeric, 2), 5.00) AS calculated_rating,
    COALESCE(ROUND(AVG(pr.punctuality_rating)::numeric, 2), 5.00) AS avg_punctuality,
    COALESCE(ROUND(AVG(pr.item_accuracy_rating)::numeric, 2), 5.00) AS avg_accuracy,
    COUNT(DISTINCT ht.id) FILTER (WHERE ht.status = 'completed') AS successful_handovers
FROM users u
LEFT JOIN peer_reviews pr ON u.id = pr.reviewee_id
LEFT JOIN handover_transactions ht ON u.id = ht.seller_id OR u.id = ht.buyer_id
GROUP BY u.id, u.full_name, u.hostel_block, u.reputation_score;

-- Pending handover schedule for safe campus physical meetups
CREATE OR REPLACE VIEW vw_pending_handover_schedule AS
SELECT 
    ht.id AS transaction_id,
    ht.scheduled_time,
    ht.final_agreed_price,
    ht.payment_method,
    ht.status AS handover_status,
    l.title AS item_title,
    hs.spot_name,
    hs.zone_code,
    hs.landmark_description,
    b.full_name AS buyer_name,
    b.phone_number AS buyer_phone,
    b.hostel_block AS buyer_hostel,
    s.full_name AS seller_name,
    s.phone_number AS seller_phone,
    s.hostel_block AS seller_hostel
FROM handover_transactions ht
JOIN listings l ON ht.listing_id = l.id
JOIN handover_spots hs ON ht.spot_id = hs.id
JOIN users b ON ht.buyer_id = b.id
JOIN users s ON ht.seller_id = s.id
WHERE ht.status IN ('scheduled', 'arrived');

COMMIT;
