-- ==============================================================================
-- HOSTEL OLX? · CP3 · Every SQL query the app uses
-- Target: PostgreSQL 15+ · tables from dbms/03_schema.sql
--
-- Each query has an id (R1… for reads, W1… for writes), a -- READ / -- WRITE tag,
-- the screen / API route of the backend (hostelOLX/backend/src/routes) that runs it,
-- and the repository function it replaces (backend/src/repositories/*.repository.js).
--
-- In the app every literal below is a bind parameter ($1, $2 …); here they are
-- filled with example ids so each query can be run and timed with
-- EXPLAIN (ANALYZE, BUFFERS) in CP4. Writes are rolled back at the end of the file.
-- "Me" (the logged-in student)  = a0000000-0000-0000-0000-000000001518
-- The "-- @R1" marker lines let a script split the file one query at a time
-- (same format as the DE repo's benchmarks/run_benchmark.sh).
-- ==============================================================================

BEGIN;   -- everything below is rolled back at the end, the sample data does not change


-- ##############################################################################
-- 1. AUTH & PROFILES                       (profile.routes.js, middleware/auth.js)
-- ##############################################################################

-- @R1
-- READ · Login: find the student by college email (unique index on users.email)
-- API: login (auth is being built; it will set req.user in middleware/auth.js from this row)
SELECT id, email, full_name, hostel_block, room_number, is_verified_student
FROM users
WHERE email = 'student1518@rishihood.edu.in';

-- @R2
-- READ · "My profile" page: private profile + counts of my listings / sales / wishlist
-- API: GET /api/profiles/me → profile.repository.findById
SELECT u.id, u.email, u.full_name, u.roll_number, u.phone_number, u.hostel_block, u.room_number,
       u.program_of_study, u.graduation_year, u.avatar_url, u.reputation_score,
       count(DISTINCT l.id) FILTER (WHERE l.status = 'active') AS active_listings,
       count(DISTINCT l.id) FILTER (WHERE l.status = 'sold')   AS items_sold,
       count(DISTINCT s.listing_id)                            AS wishlist_items
FROM users u
LEFT JOIN listings l       ON l.seller_id = u.id
LEFT JOIN saved_listings s ON s.user_id   = u.id
WHERE u.id = 'a0000000-0000-0000-0000-000000001518'
GROUP BY u.id;

-- @R3
-- READ · Public seller profile: reputation, reviews received, successful handovers
-- API: GET /api/profiles/:id → profile.service.getPublicProfile
SELECT u.id, u.full_name, u.hostel_block, u.program_of_study, u.avatar_url, u.reputation_score,
       r.total_reviews, r.avg_stars, r.avg_punctuality, r.avg_accuracy,
       (SELECT count(*) FROM handover_transactions t
        WHERE (t.seller_id = u.id OR t.buyer_id = u.id) AND t.status = 'completed') AS successful_handovers
FROM users u
LEFT JOIN LATERAL (
    SELECT count(*)                                AS total_reviews,
           round(avg(pr.rating_stars), 2)          AS avg_stars,
           round(avg(pr.punctuality_rating), 2)    AS avg_punctuality,
           round(avg(pr.item_accuracy_rating), 2)  AS avg_accuracy
    FROM peer_reviews pr
    WHERE pr.reviewee_id = u.id
) r ON TRUE
WHERE u.id = 'a0000000-0000-0000-0000-000000000024';

-- @R4
-- READ · Reviews tab of a public profile: newest reviews with the reviewer's name and item
-- API: GET /api/profiles/:id (reviews section)
SELECT pr.rating_stars, pr.review_comment, pr.punctuality_rating, pr.item_accuracy_rating, pr.created_at,
       rv.full_name AS reviewer_name, l.title AS item_title
FROM peer_reviews pr
JOIN users rv                 ON rv.id = pr.reviewer_id
JOIN handover_transactions t  ON t.id  = pr.transaction_id
JOIN listings l               ON l.id  = t.listing_id
WHERE pr.reviewee_id = 'a0000000-0000-0000-0000-000000000024'
ORDER BY pr.created_at DESC
LIMIT 20;

-- @R5
-- READ · Names/avatars for a batch of users (chat list, claim list, offer list)
-- API: profile.repository.findManyByIds / profile.service.getPublicProfileMap
SELECT id, full_name, hostel_block, avatar_url, reputation_score
FROM users
WHERE id = ANY (ARRAY['a0000000-0000-0000-0000-000000000619',
                      'a0000000-0000-0000-0000-000000000019',
                      'a0000000-0000-0000-0000-000000000995']::uuid[]);

-- @W1
-- WRITE · Edit my profile
-- API: PATCH /api/profiles/me → profile.repository.update   (updated_at is set by trigger)
UPDATE users
SET phone_number = '+919800001518', hostel_block = 'South Hostel B', room_number = '214',
    avatar_url = 'https://cdn.hostelolx.in/u/1518.jpg'
WHERE id = 'a0000000-0000-0000-0000-000000001518'
RETURNING id, full_name, phone_number, hostel_block, room_number, avatar_url, updated_at;


-- ##############################################################################
-- 2. CATEGORIES, HANDOVER SPOTS, HOMEPAGE STATS               (meta.routes.js)
-- ##############################################################################

-- @R6
-- READ · Category menu on the homepage, with number of active listings per category
-- API: GET /api/categories → category.repository.findAll
SELECT c.id, c.name, c.slug, c.icon_name, c.description, count(l.id) AS active_listings
FROM categories c
LEFT JOIN listings l ON l.category_id = c.id AND l.status = 'active'
WHERE c.is_active
GROUP BY c.id
ORDER BY c.display_order, c.name;

-- @R7
-- READ · Open a category page by its URL slug
-- API: category.repository.findBySlug
SELECT id, name, slug, icon_name, description
FROM categories
WHERE slug = 'electronics';

-- @R8
-- READ · Handover spots picker (only active spots, safest first)
-- API: GET /api/handover-spots → handoverSpot.repository.findAllActive
SELECT id, spot_name, zone_code, landmark_description, security_level, available_hours, latitude, longitude
FROM handover_spots
WHERE is_active
ORDER BY CASE security_level WHEN 'guard_station' THEN 1 WHEN 'cctv_monitored' THEN 2
                             WHEN 'high_footfall' THEN 3 ELSE 4 END, spot_name;

-- @R9
-- READ · One handover spot with the number of handovers scheduled there
-- API: GET /api/handover-spots/:id → handoverSpot.repository.findById
SELECT hs.id, hs.spot_name, hs.zone_code, hs.landmark_description, hs.security_level, hs.available_hours,
       count(t.id) FILTER (WHERE t.status IN ('scheduled', 'arrived')) AS upcoming_handovers
FROM handover_spots hs
LEFT JOIN handover_transactions t ON t.spot_id = hs.id
WHERE hs.id = '22222222-2222-2222-2222-222222222201'
GROUP BY hs.id;

-- @R10
-- READ · "Campus Pulse" homepage stats: active listings, free items, items sold, open lost & found
-- API: GET /api/stats → meta.controller.getStats
SELECT count(*) FILTER (WHERE l.status = 'active')                  AS active_listings,
       count(*) FILTER (WHERE l.status = 'active' AND l.price = 0)  AS free_items,
       count(*) FILTER (WHERE l.status = 'sold')                    AS items_sold,
       (SELECT count(*) FROM lost_found_reports WHERE status = 'open') AS open_lost_and_found
FROM listings l;


