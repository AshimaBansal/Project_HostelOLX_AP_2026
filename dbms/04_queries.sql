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


-- ##############################################################################
-- 3. LISTINGS                                               (listing.routes.js)
-- ##############################################################################

-- @R11
-- READ · Home feed: newest active listings with category, seller, handover spot and cover photo
-- API: GET /api/listings?sort=newest&page=1 → listing.repository.findAll
SELECT l.id, l.title, l.price, l.original_purchase_price, l.is_negotiable, l.listing_type, l.item_condition,
       l.created_at, c.name AS category, c.slug AS category_slug,
       u.full_name AS seller_name, u.hostel_block AS seller_hostel, u.reputation_score AS seller_rating,
       hs.spot_name AS handover_spot, img.image_url AS cover_image
FROM listings l
JOIN categories c            ON c.id  = l.category_id
JOIN users u                 ON u.id  = l.seller_id
LEFT JOIN handover_spots hs  ON hs.id = l.preferred_spot_id
LEFT JOIN LATERAL (
    SELECT li.image_url FROM listing_images li
    WHERE li.listing_id = l.id
    ORDER BY li.is_cover DESC, li.display_order
    LIMIT 1
) img ON TRUE
WHERE l.status = 'active'
ORDER BY l.created_at DESC
LIMIT 20 OFFSET 0;

-- @R12
-- READ · Browse a category with a price range, cheapest first ("price_asc" sort)
-- API: GET /api/listings?category=electronics&minPrice=100&maxPrice=1500&sort=price_asc
SELECT l.id, l.title, l.price, l.item_condition, l.listing_type, l.created_at,
       u.full_name AS seller_name, u.hostel_block AS seller_hostel
FROM listings l
JOIN categories c ON c.id = l.category_id
JOIN users u      ON u.id = l.seller_id
WHERE c.slug = 'electronics'
  AND l.status = 'active'
  AND l.price BETWEEN 100 AND 1500
ORDER BY l.price ASC, l.created_at DESC
LIMIT 20;

-- @R13
-- READ · Keyword search over title + description (uses the GIN full-text index), best match first
-- API: GET /api/listings?search=study lamp
SELECT l.id, l.title, l.price, c.name AS category, u.full_name AS seller_name,
       ts_rank(to_tsvector('english', l.title || ' ' || l.description),
               plainto_tsquery('english', 'study lamp')) AS rank
FROM listings l
JOIN categories c ON c.id = l.category_id
JOIN users u      ON u.id = l.seller_id
WHERE l.status = 'active'
  AND to_tsvector('english', l.title || ' ' || l.description) @@ plainto_tsquery('english', 'study lamp')
ORDER BY rank DESC, l.created_at DESC
LIMIT 20;

-- @R14
-- READ · Filter by listing type (free giveaways / urgent sales), newest first
-- API: GET /api/listings?listingType=giveaway
SELECT l.id, l.title, l.price, l.listing_type, l.created_at, c.name AS category, u.hostel_block AS seller_hostel
FROM listings l
JOIN categories c ON c.id = l.category_id
JOIN users u      ON u.id = l.seller_id
WHERE l.status = 'active' AND l.listing_type = 'giveaway'
ORDER BY l.created_at DESC
LIMIT 20;

-- @R15
-- READ · Listing detail page: listing + category + seller + preferred spot + "saved by me?" + #saves
-- API: GET /api/listings/:id → listing.repository.findById + listing.service.presentOne
SELECT l.id, l.title, l.description, l.price, l.original_purchase_price, l.is_negotiable, l.listing_type,
       l.item_condition, l.status, l.view_count, l.created_at, l.updated_at,
       c.name AS category, c.slug AS category_slug,
       u.id AS seller_id, u.full_name AS seller_name, u.hostel_block AS seller_hostel, u.reputation_score AS seller_rating,
       hs.spot_name, hs.landmark_description, hs.security_level,
       EXISTS (SELECT 1 FROM saved_listings s
               WHERE s.listing_id = l.id AND s.user_id = 'a0000000-0000-0000-0000-000000001518') AS saved_by_me,
       (SELECT count(*) FROM saved_listings s WHERE s.listing_id = l.id) AS saves
FROM listings l
JOIN categories c           ON c.id  = l.category_id
JOIN users u                ON u.id  = l.seller_id
LEFT JOIN handover_spots hs ON hs.id = l.preferred_spot_id
WHERE l.id = 'b0000000-0000-0000-0000-000000000001';

-- @R16
-- READ · Photo gallery of a listing (cover first)
-- API: GET /api/listings/:id (images)
SELECT li.id, li.image_url, li.is_cover, li.display_order
FROM listing_images li
JOIN listings l ON l.id = li.listing_id
WHERE l.id = 'b0000000-0000-0000-0000-000000000001'
ORDER BY li.is_cover DESC, li.display_order;

-- @R17
-- READ · "My listings" dashboard: all my listings with saves and pending offers per listing
-- API: GET /api/listings?sellerId=me → listing.repository.findAll({ sellerId })
SELECT l.id, l.title, l.price, l.status, l.view_count, l.created_at,
       count(DISTINCT s.user_id)                                 AS saves,
       count(DISTINCT o.id) FILTER (WHERE o.status = 'pending')  AS pending_offers
FROM listings l
LEFT JOIN saved_listings s ON s.listing_id = l.id
LEFT JOIN price_offers o   ON o.listing_id = l.id
WHERE l.seller_id = 'a0000000-0000-0000-0000-000000001518'
GROUP BY l.id
ORDER BY l.created_at DESC;

-- @R18
-- READ · Ownership check before edit / status change / delete (only the seller may change it)
-- API: listing.service.getOwnedOrFail
SELECT id, seller_id, status
FROM listings
WHERE id = 'b0000000-0000-0000-0000-000000004931'
  AND seller_id = 'a0000000-0000-0000-0000-000000001518';

-- @W2
-- WRITE · Post a new listing ("Sell an item" page)
-- API: POST /api/listings → listing.repository.create
INSERT INTO listings (seller_id, category_id, preferred_spot_id, title, description, price,
                      original_purchase_price, is_negotiable, listing_type, item_condition)
VALUES ('a0000000-0000-0000-0000-000000001518', '11111111-1111-1111-1111-111111111103',
        '22222222-2222-2222-2222-222222222201', 'Logitech K380 Keyboard',
        'Bluetooth keyboard, 6 months old, works with laptop and phone', 1200.00, 2500.00,
        TRUE, 'sale', 'like_new')
RETURNING id, status, created_at;

-- @W3
-- WRITE · Upload photos for the new listing (one row per photo)
-- API: POST /api/listings (images[])
INSERT INTO listing_images (listing_id, image_url, is_cover, display_order)
VALUES ('b0000000-0000-0000-0000-000000004931', 'https://cdn.hostelolx.in/l/4931/new-0.jpg', FALSE, 3),
       ('b0000000-0000-0000-0000-000000004931', 'https://cdn.hostelolx.in/l/4931/new-1.jpg', FALSE, 4);

-- @W4
-- WRITE · Edit my listing (only if I am the seller)
-- API: PATCH /api/listings/:id → listing.repository.update
UPDATE listings
SET title = 'Study Lamp (barely used) - price dropped', price = 3999.00, is_negotiable = FALSE
WHERE id = 'b0000000-0000-0000-0000-000000004931'
  AND seller_id = 'a0000000-0000-0000-0000-000000001518'
RETURNING id, title, price, updated_at;

-- @W5
-- WRITE · Change listing status (mark as reserved / sold)
-- API: PATCH /api/listings/:id/status → listing.service.updateStatus
UPDATE listings
SET status = 'sold'
WHERE id = 'b0000000-0000-0000-0000-000000004931'
  AND seller_id = 'a0000000-0000-0000-0000-000000001518'
RETURNING id, status;

-- @W6
-- WRITE · Delete my listing (soft delete, so offers / chats / handovers keep their history)
-- API: DELETE /api/listings/:id → listing.service.remove
UPDATE listings
SET status = 'delisted'
WHERE id = 'b0000000-0000-0000-0000-000000007931'
  AND seller_id = 'a0000000-0000-0000-0000-000000001518'
  AND status <> 'sold';

-- @W7
-- WRITE · Count a view when someone opens the listing page
-- API: GET /api/listings/:id
UPDATE listings
SET view_count = view_count + 1
WHERE id = 'b0000000-0000-0000-0000-000000000001';


-- ##############################################################################
-- 4. WISHLIST                                              (wishlist.routes.js)
-- ##############################################################################

-- @R19
-- READ · My wishlist: saved listings with price, status, seller and cover photo, newest save first
-- API: GET /api/wishlist → wishlist.repository.findByUser + listing.repository.findManyByIds
SELECT s.listing_id, s.personal_note, s.created_at AS saved_at,
       l.title, l.price, l.status, u.full_name AS seller_name, img.image_url AS cover_image
FROM saved_listings s
JOIN listings l ON l.id = s.listing_id
JOIN users u    ON u.id = l.seller_id
LEFT JOIN LATERAL (
    SELECT li.image_url FROM listing_images li
    WHERE li.listing_id = l.id ORDER BY li.is_cover DESC, li.display_order LIMIT 1
) img ON TRUE
WHERE s.user_id = 'a0000000-0000-0000-0000-000000001518'
ORDER BY s.created_at DESC;

-- @R20
-- READ · Is this listing already in my wishlist? (heart icon state)
-- API: wishlist.repository.exists
SELECT EXISTS (SELECT 1 FROM saved_listings
               WHERE user_id = 'a0000000-0000-0000-0000-000000001518'
                 AND listing_id = 'b0000000-0000-0000-0000-000000000001') AS is_saved;

-- @W8
-- WRITE · Add to wishlist (ignore if already saved)
-- API: POST /api/wishlist/:listingId → wishlist.repository.add
INSERT INTO saved_listings (user_id, listing_id, personal_note)
VALUES ('a0000000-0000-0000-0000-000000001518', 'b0000000-0000-0000-0000-000000000001', 'check if lamp has warm light')
ON CONFLICT (user_id, listing_id) DO NOTHING;

-- @W9
-- WRITE · Remove from wishlist
-- API: DELETE /api/wishlist/:listingId → wishlist.repository.remove
DELETE FROM saved_listings
WHERE user_id = 'a0000000-0000-0000-0000-000000001518'
  AND listing_id = 'b0000000-0000-0000-0000-000000001124';


-- ##############################################################################
-- 5. PRICE OFFERS (OLX BARGAINING)   tables in 03_schema.sql; API routes not built yet
-- ##############################################################################

-- @R21
-- READ · Offers received on my listing (seller view), highest first, with buyer reputation
SELECT o.id, o.offered_amount, o.counter_amount, o.buyer_note, o.status, o.expires_at, o.created_at,
       b.full_name AS buyer_name, b.hostel_block AS buyer_hostel, b.reputation_score AS buyer_rating
FROM price_offers o
JOIN listings l ON l.id = o.listing_id
JOIN users b    ON b.id = o.buyer_id
WHERE o.listing_id = 'b0000000-0000-0000-0000-000000004931'
  AND l.seller_id  = 'a0000000-0000-0000-0000-000000001518'
ORDER BY o.offered_amount DESC, o.created_at;

-- @R22
-- READ · "My offers" (buyer view): offers I made, with listing and seller
SELECT o.id, o.offered_amount, o.counter_amount, o.status, o.expires_at,
       l.id AS listing_id, l.title, l.price AS asking_price, l.status AS listing_status, s.full_name AS seller_name
FROM price_offers o
JOIN listings l ON l.id = o.listing_id
JOIN users s    ON s.id = l.seller_id
WHERE o.buyer_id = 'a0000000-0000-0000-0000-000000001518'
ORDER BY o.created_at DESC;

-- @W10
-- WRITE · Make an offer on a listing (valid for 48 hours)
INSERT INTO price_offers (listing_id, buyer_id, offered_amount, buyer_note, expires_at)
VALUES ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000001518', 400.00,
        'Can pick up from North Hostel today', CURRENT_TIMESTAMP + INTERVAL '48 hours')
RETURNING id, status, expires_at;

-- @W11
-- WRITE · Seller counters or accepts a pending offer (only on their own listing)
UPDATE price_offers o
SET status = 'accepted'
FROM listings l
WHERE o.id = 'c0000000-0000-0000-0000-000000008310'
  AND l.id = o.listing_id
  AND l.seller_id = 'a0000000-0000-0000-0000-000000001518'
  AND o.status IN ('pending', 'countered')
RETURNING o.id, o.status;

-- @W12
-- WRITE · Batch job: expire pending offers whose time ran out
UPDATE price_offers
SET status = 'expired'
WHERE status IN ('pending', 'countered')
  AND expires_at < CURRENT_TIMESTAMP;


-- ##############################################################################
-- 6. HANDOVER TRANSACTIONS & PEER REVIEWS   tables in 03_schema.sql; API routes not built yet
-- ##############################################################################

-- @R23
-- READ · My upcoming handovers (as buyer or seller) with item, spot and the other student's phone
SELECT t.id, t.scheduled_time, t.final_agreed_price, t.payment_method, t.status,
       l.title AS item, hs.spot_name, hs.landmark_description,
       CASE WHEN t.buyer_id = 'a0000000-0000-0000-0000-000000001518' THEN 'buying' ELSE 'selling' END AS my_role,
       other.full_name AS other_party, other.phone_number AS other_phone
FROM handover_transactions t
JOIN listings l        ON l.id  = t.listing_id
JOIN handover_spots hs ON hs.id = t.spot_id
JOIN users other       ON other.id = CASE WHEN t.buyer_id = 'a0000000-0000-0000-0000-000000001518'
                                          THEN t.seller_id ELSE t.buyer_id END
WHERE (t.buyer_id = 'a0000000-0000-0000-0000-000000001518' OR t.seller_id = 'a0000000-0000-0000-0000-000000001518')
  AND t.status IN ('scheduled', 'arrived')
ORDER BY t.scheduled_time;

-- @R24
-- READ · Handover history (completed) and whether I already left a review
SELECT t.id, t.completed_at, t.final_agreed_price, l.title AS item,
       EXISTS (SELECT 1 FROM peer_reviews pr
               WHERE pr.transaction_id = t.id AND pr.reviewer_id = 'a0000000-0000-0000-0000-000000001662') AS reviewed
FROM handover_transactions t
JOIN listings l ON l.id = t.listing_id
WHERE (t.buyer_id = 'a0000000-0000-0000-0000-000000001662' OR t.seller_id = 'a0000000-0000-0000-0000-000000001662')
  AND t.status = 'completed'
ORDER BY t.completed_at DESC;

-- @W13
-- WRITE · Schedule a handover after the seller accepts an offer
INSERT INTO handover_transactions (listing_id, buyer_id, seller_id, accepted_offer_id, spot_id,
                                   final_agreed_price, payment_method, verification_pin, scheduled_time)
SELECT o.listing_id, o.buyer_id, l.seller_id, o.id, '22222222-2222-2222-2222-222222222201',
       coalesce(o.counter_amount, o.offered_amount), 'upi_on_spot',
       lpad((floor(random() * 1000000))::int::text, 6, '0'), CURRENT_TIMESTAMP + INTERVAL '1 day'
FROM price_offers o
JOIN listings l ON l.id = o.listing_id
WHERE o.id = 'c0000000-0000-0000-0000-000000008310'
RETURNING id, verification_pin, scheduled_time;

-- @W14
-- WRITE · Complete the handover: seller enters the buyer's 6-digit PIN
UPDATE handover_transactions
SET status = 'completed', completed_at = CURRENT_TIMESTAMP
WHERE id = 'd0000000-0000-0000-0000-000000000330'
  AND verification_pin = '111443'
  AND status IN ('scheduled', 'arrived')
RETURNING id, status, completed_at;

-- @W15
-- WRITE · Mark the listing as sold once its handover is completed
UPDATE listings l
SET status = 'sold'
FROM handover_transactions t
WHERE t.id = 'd0000000-0000-0000-0000-000000000330'
  AND l.id = t.listing_id;

-- @W16
-- WRITE · Buyer reviews the seller after a completed handover (one review per person per handover)
INSERT INTO peer_reviews (transaction_id, reviewer_id, reviewee_id, rating_stars, review_comment,
                          punctuality_rating, item_accuracy_rating)
VALUES ('d0000000-0000-0000-0000-000000000025', 'a0000000-0000-0000-0000-000000001662',
        'a0000000-0000-0000-0000-000000000179', 5, 'On time and the item was exactly as shown', 5, 5);

-- @W17
-- WRITE · Recompute the seller's reputation score from all reviews they received
UPDATE users u
SET reputation_score = r.avg_stars
FROM (SELECT reviewee_id, round(avg(rating_stars), 2) AS avg_stars
      FROM peer_reviews
      WHERE reviewee_id = 'a0000000-0000-0000-0000-000000000179'
      GROUP BY reviewee_id) r
WHERE u.id = r.reviewee_id;


-- ##############################################################################
-- 7. CHAT                                  (chat.routes.js, mounted at /api/conversations)
-- ##############################################################################

-- @R25
-- READ · My conversations: listing, other student, last message, unread count, newest first
-- API: GET /api/conversations → conversation.repository.findForUser + findLastMessage + countUnread
SELECT c.id, c.last_message_at, l.id AS listing_id, l.title, l.price,
       other.full_name AS other_party, lm.message_body AS last_message, lm.sent_at AS last_sent_at,
       (SELECT count(*) FROM chat_messages m
        WHERE m.channel_id = c.id AND NOT m.is_read
          AND m.sender_id <> 'a0000000-0000-0000-0000-000000001518') AS unread
FROM chat_channels c
JOIN listings l  ON l.id = c.listing_id
JOIN users other ON other.id = CASE WHEN c.buyer_id = 'a0000000-0000-0000-0000-000000001518'
                                    THEN c.seller_id ELSE c.buyer_id END
LEFT JOIN LATERAL (
    SELECT m.message_body, m.sent_at FROM chat_messages m
    WHERE m.channel_id = c.id ORDER BY m.sent_at DESC LIMIT 1
) lm ON TRUE
WHERE (c.buyer_id = 'a0000000-0000-0000-0000-000000001518' OR c.seller_id = 'a0000000-0000-0000-0000-000000001518')
  AND c.is_active
ORDER BY c.last_message_at DESC;

-- @R26
-- READ · Open one conversation (check that I am a member)
-- API: GET /api/conversations/:id → conversation.repository.findById
SELECT c.id, c.listing_id, c.buyer_id, c.seller_id, c.is_active, l.title, l.status AS listing_status
FROM chat_channels c
JOIN listings l ON l.id = c.listing_id
WHERE c.id = 'e0000000-0000-0000-0000-000000005586'
  AND 'a0000000-0000-0000-0000-000000001518' IN (c.buyer_id, c.seller_id);

-- @R27
-- READ · Messages of a conversation, oldest first, with sender name
-- API: GET /api/conversations/:id/messages → conversation.repository.findMessages
SELECT m.id, m.sender_id, u.full_name AS sender_name, m.message_body, m.message_type, m.is_read, m.sent_at
FROM chat_messages m
JOIN users u ON u.id = m.sender_id
WHERE m.channel_id = 'e0000000-0000-0000-0000-000000005586'
ORDER BY m.sent_at, m.id;

-- @R28
-- READ · Unread badge: total unread messages for me across all my conversations
-- API: GET /api/conversations/unread-count → chat.service.getUnreadTotal
SELECT count(*) AS unread_total
FROM chat_messages m
JOIN chat_channels c ON c.id = m.channel_id
WHERE (c.buyer_id = 'a0000000-0000-0000-0000-000000001518' OR c.seller_id = 'a0000000-0000-0000-0000-000000001518')
  AND m.sender_id <> 'a0000000-0000-0000-0000-000000001518'
  AND NOT m.is_read;

-- @R29
-- READ · "Chat with seller": is there already a conversation for this listing and buyer?
-- API: POST /api/conversations → conversation.repository.findExisting
SELECT c.id
FROM chat_channels c
JOIN listings l ON l.id = c.listing_id
WHERE c.listing_id = 'b0000000-0000-0000-0000-000000000001'
  AND c.buyer_id   = 'a0000000-0000-0000-0000-000000001518'
  AND c.seller_id  = l.seller_id;

-- @W18
-- WRITE · Start a conversation with the seller (seller taken from the listing)
-- API: POST /api/conversations → conversation.repository.create
INSERT INTO chat_channels (listing_id, buyer_id, seller_id)
SELECT l.id, 'a0000000-0000-0000-0000-000000001518', l.seller_id
FROM listings l
WHERE l.id = 'b0000000-0000-0000-0000-000000000001'
ON CONFLICT (listing_id, buyer_id, seller_id) DO NOTHING
RETURNING id;

-- @W19
-- WRITE · Send a message
-- API: POST /api/conversations/:id/messages → conversation.repository.addMessage
INSERT INTO chat_messages (channel_id, sender_id, message_body, message_type)
VALUES ('e0000000-0000-0000-0000-000000005586', 'a0000000-0000-0000-0000-000000001518',
        'Yes, still available. Can meet at North Hostel A foyer at 6 pm', 'text')
RETURNING id, sent_at;

-- @W20
-- WRITE · Move the conversation to the top of the list after a new message
-- API: conversation.repository.touch
UPDATE chat_channels
SET last_message_at = CURRENT_TIMESTAMP
WHERE id = 'e0000000-0000-0000-0000-000000005586';

-- @W21
-- WRITE · Mark the other student's messages in this conversation as read
-- API: PATCH /api/conversations/:id/read → conversation.repository.markRead
UPDATE chat_messages
SET is_read = TRUE
WHERE channel_id = 'e0000000-0000-0000-0000-000000005586'
  AND sender_id <> 'a0000000-0000-0000-0000-000000001518'
  AND NOT is_read;


-- ##############################################################################
-- 8. LOST & FOUND + CLAIMS                        (lostFound.routes.js, claim.routes.js)
-- ##############################################################################

-- @R30
-- READ · Lost & found board: open "lost" items, keyword search, newest first, with claim counts
-- API: GET /api/lost-found?type=lost&q=bottle → lostFound.repository.findAll
SELECT r.id, r.report_type, r.item_name, r.last_seen_location, r.event_date, r.custody_location, r.status,
       c.name AS category, u.full_name AS reported_by, count(cr.id) AS claims
FROM lost_found_reports r
JOIN users u               ON u.id = r.reporter_id
LEFT JOIN categories c     ON c.id = r.category_id
LEFT JOIN claim_requests cr ON cr.report_id = r.id
WHERE r.status = 'open'
  AND r.report_type = 'lost'
  AND (r.item_name ILIKE '%bottle%' OR r.description ILIKE '%bottle%' OR r.last_seen_location ILIKE '%bottle%')
GROUP BY r.id, c.name, u.full_name
ORDER BY r.created_at DESC
LIMIT 20;

-- @R31
-- READ · One lost & found report with the reporter's contact
-- API: GET /api/lost-found/:id → lostFound.repository.findById
SELECT r.*, u.full_name AS reported_by, u.hostel_block, u.phone_number, c.name AS category
FROM lost_found_reports r
JOIN users u           ON u.id = r.reporter_id
LEFT JOIN categories c ON c.id = r.category_id
WHERE r.id = 'f0000000-0000-0000-0000-000000001501';

-- @R32
-- READ · Claims on my report (only the reporter sees them), newest first
-- API: GET /api/lost-found/:id/claims → claim.repository.findByItem
SELECT cr.id, cr.proof_description, cr.identifying_features, cr.contact_phone, cr.status, cr.created_at,
       u.full_name AS claimant_name, u.hostel_block AS claimant_hostel
FROM claim_requests cr
JOIN lost_found_reports r ON r.id = cr.report_id
JOIN users u              ON u.id = cr.claimant_id
WHERE cr.report_id  = 'f0000000-0000-0000-0000-000000001501'
  AND r.reporter_id = 'a0000000-0000-0000-0000-000000001518'
ORDER BY cr.created_at DESC;

-- @R33
-- READ · "My claims": claims I made, with the item and its current status
-- API: GET /api/claims/mine → claim.repository.findByClaimant
SELECT cr.id, cr.status AS claim_status, cr.created_at,
       r.id AS report_id, r.item_name, r.report_type, r.status AS report_status, r.custody_location
FROM claim_requests cr
JOIN lost_found_reports r ON r.id = cr.report_id
WHERE cr.claimant_id = 'a0000000-0000-0000-0000-000000001518'
ORDER BY cr.created_at DESC;

-- @R34
-- READ · Have I already claimed this item? (claim.repository.findExisting)
SELECT id, status
FROM claim_requests
WHERE report_id = 'f0000000-0000-0000-0000-000000000001'
  AND claimant_id = 'a0000000-0000-0000-0000-000000001518';

-- @W22
-- WRITE · Report a lost or found item
-- API: POST /api/lost-found → lostFound.repository.create
INSERT INTO lost_found_reports (reporter_id, category_id, report_type, item_name, description,
                                last_seen_location, event_date, image_url, custody_location)
VALUES ('a0000000-0000-0000-0000-000000001518', '11111111-1111-1111-1111-111111111103', 'found',
        'Black Boat earphones', 'Found on the 2nd floor reading table, left side', 'Library 2nd floor',
        CURRENT_DATE, 'https://cdn.hostelolx.in/lf/earphones.jpg', 'Library front desk')
RETURNING id, status;

-- @W23
-- WRITE · Edit my report (only the reporter)
-- API: PATCH /api/lost-found/:id → lostFound.repository.update
UPDATE lost_found_reports
SET custody_location = 'Security desk, North Hostel A', description = description || ' (handed to security)'
WHERE id = 'f0000000-0000-0000-0000-000000001501'
  AND reporter_id = 'a0000000-0000-0000-0000-000000001518';

-- @W24
-- WRITE · Claim an item; re-claiming after withdrawing sets it back to pending
-- API: POST /api/lost-found/:id/claims → claim.repository.create / updateStatus
INSERT INTO claim_requests (report_id, claimant_id, proof_description, identifying_features, contact_phone)
VALUES ('f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000001518',
        'Lost it after the DBMS lab on Monday', 'Sticker of a cat on the cap', '+919800001518')
ON CONFLICT (report_id, claimant_id) DO UPDATE
SET status = 'pending', proof_description = EXCLUDED.proof_description
RETURNING id, status;

-- @W25
-- WRITE · Reporter approves one claim
-- API: PATCH /api/claims/:id → claim.repository.updateStatus
UPDATE claim_requests cr
SET status = 'approved', resolution_remarks = 'Verified the sticker on the cap'
FROM lost_found_reports r
WHERE cr.report_id = 'f0000000-0000-0000-0000-000000001501'
  AND cr.claimant_id = 'a0000000-0000-0000-0000-000000001501'
  AND r.id = cr.report_id
  AND r.reporter_id = 'a0000000-0000-0000-0000-000000001518'
RETURNING cr.id, cr.status;

-- @W26
-- WRITE · …and every other pending claim on that item is rejected
-- API: claim.repository.rejectOtherPending
UPDATE claim_requests
SET status = 'rejected', resolution_remarks = 'Another claim was approved'
WHERE report_id = 'f0000000-0000-0000-0000-000000001501'
  AND claimant_id <> 'a0000000-0000-0000-0000-000000001501'
  AND status IN ('pending', 'under_verification');

-- @W27
-- WRITE · …and the report is closed as resolved
-- API: lostFound.repository.update({ status })
UPDATE lost_found_reports
SET status = 'resolved'
WHERE id = 'f0000000-0000-0000-0000-000000001501';


-- ##############################################################################
-- 9. SAFETY & MODERATION   table in 03_schema.sql; API routes not built yet
-- ##############################################################################

-- @R35
-- READ · Moderation queue: pending safety reports with reporter, reported user and listing
SELECT sr.id, sr.violation_category, sr.report_details, sr.status, sr.created_at,
       rep.full_name AS reported_by, ru.full_name AS reported_user, l.title AS reported_listing
FROM safety_reports sr
JOIN users rep       ON rep.id = sr.reporter_id
LEFT JOIN users ru   ON ru.id  = sr.reported_user_id
LEFT JOIN listings l ON l.id   = sr.reported_listing_id
WHERE sr.status IN ('pending', 'investigating')
ORDER BY sr.created_at
LIMIT 50;

-- @W28
-- WRITE · Report a listing / seller from the listing page
INSERT INTO safety_reports (reporter_id, reported_user_id, reported_listing_id, violation_category, report_details)
SELECT 'a0000000-0000-0000-0000-000000001518', l.seller_id, l.id, 'scam_pricing',
       'Asking price is higher than a new one on Amazon'
FROM listings l
WHERE l.id = 'b0000000-0000-0000-0000-000000000001';

-- @END
ROLLBACK;
