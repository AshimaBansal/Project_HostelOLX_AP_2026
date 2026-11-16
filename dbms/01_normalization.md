# Database Normalization – Hostel OLX? Student Marketplace

## 1. Domain Overview

**Hostel OLX?** is a local-first student marketplace for Rishihood University. It allows students from the approved university email domains to browse, publish and manage listings, save items, communicate with sellers, and report or claim lost-and-found items.

The marketplace supports the following main activities:

- Maintaining student profiles.
- Organizing marketplace listings into categories.
- Publishing listings with prices, descriptions, conditions and availability status.
- Storing multiple photographs for a listing.
- Allowing students to save listings to wishlists.
- Creating conversations between buyers and sellers.
- Storing messages and conversation read-state information.
- Publishing lost-and-found item reports.
- Managing claims made against lost-and-found items.
- Maintaining campus handover locations.

The database uses PostgreSQL-compatible relational design in its documented migration and supports local SQLite/Turso deployment in the wider application architecture. This document analyzes the relational structure represented by the supplied PostgreSQL migration.

The purpose of normalization is to organize data into relations that reduce unnecessary duplication, preserve consistency and avoid insertion, update and deletion anomalies.

## 2. Unnormalized Form (UNF)

### 2.1 Description of UNF

Unnormalized Form (UNF) represents data before repeating groups and multivalued attributes have been separated into individual relations.

A simple marketplace record could combine a student's profile, their listings, listing photographs, wishlists, conversations, messages and lost-and-found activity in one large structure.

Such a structure could contain repeating groups. For example:

- A student can publish multiple listings.
- A listing can have multiple photographs.
- A student can save multiple listings.
- A listing can have conversations with different buyers.
- A conversation can contain multiple messages.
- A lost-and-found item can receive claims from different students.

### 2.2 Example of a conceptual UNF structure

The following is a conceptual illustration of an unnormalized marketplace record. It is not an actual SQL table.

```text
MARKETPLACE_UNF(
    university_user {
        profile_id,
        full_name,
        phone,
        academic_role,
        hostel_name,
        room_number,
        listings {
            listing_id,
            title,
            description,
            category,
            price,
            condition,
            status,
            images {
                image_url,
                display_order
            },
            wishlists {
                saved_by_user,
                saved_at
            },
            conversations {
                buyer,
                seller,
                messages {
                    sender,
                    message_text,
                    sent_at
                }
            }
        },
        lost_found_items {
            item_type,
            title,
            description,
            location,
            claims {
                claimant,
                claim_message,
                claim_status
            }
        }
    },
    handover_spots {
        name,
        timings,
        location_description,
        latitude,
        longitude
    }
)
```

### 2.3 Problems in UNF

**1. Repeating groups**

A listing may have multiple images and a conversation may contain multiple messages. Storing these as lists inside one record creates repeating groups.

**2. Data redundancy**

Student profile details could be repeated for every listing, wishlist entry or message associated with the same student.

**3. Insertion anomaly**

A new handover spot or category could be difficult to store if the design requires an associated listing or transaction.

**4. Update anomaly**

If a student's profile details are copied into several records, changing the details may require updating every occurrence. Missing an update can create inconsistent information.

**5. Deletion anomaly**

Deleting a listing could accidentally remove its only stored copy of related information, such as image or conversation details, if all information is embedded in one large record.

Therefore, the data should be divided into separate relations, with each attribute holding one value and relationships maintained through keys.

## 3. First Normal Form (1NF)

### 3.1 Rules of 1NF

A relation is in First Normal Form (1NF) when:

- Every column contains a single, atomic value.
- Each row can be uniquely identified by a key.
- There are no repeating groups or multivalued attributes inside a cell.
- Values in a column represent the same type of attribute.

### 3.2 Applying 1NF to the marketplace

The repeating groups in the conceptual UNF structure are represented as separate rows in their own relations.

For example:

- Each listing is stored as an individual row in `listings`.
- Each photograph is stored as an individual row in `listing_images`.
- Each saved listing is stored as an individual row in `wishlists`.
- Each conversation is stored as an individual row in `conversations`.
- Each message is stored as an individual row in `messages`.
- Each participant's conversation read-state is stored as an individual row in `conversation_members`.
- Each lost-and-found item and each claim is stored as an individual row in `lost_found_items` and `claims`.

### 3.3 Example of an atomic relation

Consider a conceptual relation combining a student, a listing and a listing photograph:

```text
STUDENT_LISTING_IMAGE_1NF(
    profile_id,
    full_name,
    listing_id,
    title,
    price,
    image_id,
    image_url,
    display_order
)
```

Each row represents one photograph belonging to one listing, together with its seller's details.

A listing with six photographs would be represented by six rows rather than storing six image URLs in one cell.

The example is used only to explain the normalization process. It is not an additional table in the final schema.

### 3.4 Functional dependencies in the example

The functional dependencies are:

```text
profile_id → full_name

listing_id → profile_id, title, price

image_id → listing_id, image_url, display_order
```

The key for the illustrative relation is `image_id`, assuming each image row has its own unique identifier.

Although values are atomic, profile and listing details are repeated across the rows for different images. The final design therefore keeps profiles, listings and listing images in separate relations.

### 3.5 Result of 1NF

The repeating groups have been represented as individual records, and each attribute contains an atomic value.

The final schema uses primary keys to identify records and foreign keys to connect related records. The next step is to check whether non-key attributes depend on complete candidate keys.

## 4. Second Normal Form (2NF)

### 4.1 Rules of 2NF

A relation is in Second Normal Form (2NF) when:

- It is already in 1NF.
- Every non-prime attribute is fully functionally dependent on every candidate key.
- No non-key attribute depends on only part of a composite candidate key.

A relation whose candidate keys contain only one attribute automatically satisfies 2NF if it is in 1NF.

### 4.2 Example of a partial dependency

Consider a conceptual relation that combines wishlist data with student and listing details:

```text
WISHLIST_DETAILS_1NF(
    user_id,
    listing_id,
    created_at,
    full_name,
    listing_title,
    price
)
```

The composite key is:

```text
(user_id, listing_id)
```

The functional dependencies include:

```text
user_id → full_name

listing_id → listing_title, price

(user_id, listing_id) → created_at
```

`full_name` depends only on `user_id`, and listing details depend only on `listing_id`. These are partial dependencies on parts of the composite key.

### 4.3 Decomposition to remove partial dependencies

The relation can be separated into:

```text
PROFILES(
    id PRIMARY KEY,
    full_name,
    ...
)

LISTINGS(
    id PRIMARY KEY,
    title,
    price,
    ...
)

WISHLISTS(
    user_id,
    listing_id,
    created_at,
    PRIMARY KEY (user_id, listing_id)
)
```

The foreign keys in `WISHLISTS` refer to `PROFILES(id)` and `LISTINGS(id)`. Student and listing details are stored once in their respective relations.

### 4.4 2NF analysis of the actual schema

The actual migration has two relations with composite primary keys:

| Relation | Composite primary key | Non-key attributes |
|---|---|---|
| `wishlists` | `(user_id, listing_id)` | `created_at` |
| `conversation_members` | `(conversation_id, user_id)` | `last_read_at`, `joined_at` |

For `wishlists`, `created_at` depends on the complete combination of `user_id` and `listing_id`.

For `conversation_members`, `last_read_at` and `joined_at` depend on the complete combination of `conversation_id` and `user_id`. The read position belongs to a particular participant in a particular conversation.

The other relations use single-column primary keys. They therefore have no partial dependency on a part of a composite primary key.

The schema also has alternate candidate keys in `categories`, `conversations` and `claims`. Their non-key attributes are determined by the complete alternate key, as discussed in the functional-dependency summary.

Therefore, no partial dependencies are identified in the actual relations, and the schema satisfies 2NF.

## 5. Third Normal Form (3NF)

### 5.1 Rules of 3NF

A relation is in Third Normal Form (3NF) when:

- It is already in 2NF.
- It has no transitive dependency of a non-key attribute on a candidate key.

A transitive dependency occurs when a key determines a non-key attribute through another non-key attribute.

Formally, for every non-trivial functional dependency `X → A`, at least one of the following must be true:

- `X` is a superkey.
- `A` is a prime attribute (an attribute that belongs to at least one candidate key).

### 5.2 Separating independent entities

The schema stores categories separately from listings.

If the category name were copied into every listing, a category name could be repeated across many listing records. The actual design uses:

```text
CATEGORIES(
    id PRIMARY KEY,
    name UNIQUE,
    slug UNIQUE
)

LISTINGS(
    id PRIMARY KEY,
    category_id,
    ...
)
```

The `category_id` in `listings` references `categories(id)`. Category names and slugs are maintained in one relation.

Similarly, student profile details are stored in `profiles`, while listing records refer to the seller through `seller_id`. Message records refer to their sender through `sender_id`, rather than repeating the sender's profile details in each message.

### 5.3 3NF analysis of the actual relations

| Relation | 3NF justification |
|---|---|
| `profiles` | Profile attributes depend on the primary key `id`. |
| `categories` | Category attributes depend on `id`; `name` and `slug` are unique candidate keys. |
| `listings` | Listing attributes depend on `id`. Seller and category details are stored in their own relations. |
| `listing_images` | Image attributes depend on `id`; listing details are stored in `listings`. |
| `wishlists` | `created_at` depends on the complete key `(user_id, listing_id)`. |
| `conversations` | Conversation attributes depend on `id` and the unique combination `(listing_id, buyer_id, seller_id)`. |
| `messages` | Message attributes depend on `id`; conversation and sender details are referenced through foreign keys. |
| `conversation_members` | Read-state and join-time attributes depend on `(conversation_id, user_id)`. |
| `lost_found_items` | Lost-and-found item attributes depend on `id`; poster profile details are stored in `profiles`. |
| `claims` | Claim attributes depend on `id` and the unique pair `(item_id, claimant_id)`. |
| `handover_spots` | Handover spot attributes depend on `id`; `name` is also unique. |

No transitive dependencies among non-key attributes are identified from the functional dependencies declared by the schema.

Therefore, all 11 relations satisfy 3NF based on the defined schema constraints and functional dependencies.

## 6. Boyce-Codd Normal Form (BCNF)

### 6.1 Rules of BCNF

Boyce-Codd Normal Form is a stronger form of 3NF.

A relation is in BCNF if, for every non-trivial functional dependency:

```text
X → Y
```

`X` is a superkey of that relation.

In other words, every determinant of a non-trivial functional dependency must be a candidate key or a superkey.

### 6.2 Candidate keys in the schema

The candidate keys established by primary-key and unique constraints are:

| Relation | Candidate key(s) |
|---|---|
| `profiles` | `id` |
| `categories` | `id`, `name`, `slug` |
| `listings` | `id` |
| `listing_images` | `id` |
| `wishlists` | `(user_id, listing_id)` |
| `conversations` | `id`, `(listing_id, buyer_id, seller_id)` |
| `messages` | `id` |
| `conversation_members` | `(conversation_id, user_id)` |
| `lost_found_items` | `id` |
| `claims` | `id`, `(item_id, claimant_id)` |
| `handover_spots` | `id`, `name` |

### 6.3 BCNF analysis

| Relation | Non-trivial determinants | BCNF justification |
|---|---|---|
| `profiles` | `id` | Primary key determines the other profile attributes. |
| `categories` | `id`, `name`, `slug` | Each determinant is a candidate key because all three are primary-key or unique attributes. |
| `listings` | `id` | Primary key determines the listing attributes. |
| `listing_images` | `id` | Primary key determines the image attributes. |
| `wishlists` | `(user_id, listing_id)` | The complete composite key determines `created_at`. |
| `conversations` | `id`, `(listing_id, buyer_id, seller_id)` | Both are candidate keys under the primary-key and unique constraints. |
| `messages` | `id` | Primary key determines the message attributes. |
| `conversation_members` | `(conversation_id, user_id)` | The complete composite key determines the participant read-state attributes. |
| `lost_found_items` | `id` | Primary key determines the item attributes. |
| `claims` | `id`, `(item_id, claimant_id)` | Both are candidate keys under the primary-key and unique constraints. |
| `handover_spots` | `id`, `name` | Both are candidate keys under the primary-key and unique constraints. |

Based on the functional dependencies established by the declared primary-key and unique constraints, every non-trivial determinant is a candidate key or superkey.

Therefore, all 11 relations satisfy BCNF under the stated dependencies.

## 7. Functional Dependencies and Candidate-Key Summary

The following table summarizes the principal functional dependencies of the actual schema. The ellipsis represents the remaining non-key attributes in the corresponding relation.

| Relation | Candidate key(s) | Principal functional dependency |
|---|---|---|
| `profiles` | `id` | `id → full_name, phone, academic_role, hostel_name, room_number, avatar_url, created_at, updated_at` |
| `categories` | `id`, `name`, `slug` | `id → name, slug`; `name → id, slug`; `slug → id, name` |
| `listings` | `id` | `id → seller_id, category_id, title, description, price, original_price, listing_type, item_condition, status, location_text, is_featured, created_at, updated_at` |
| `listing_images` | `id` | `id → listing_id, image_url, display_order, created_at` |
| `wishlists` | `(user_id, listing_id)` | `(user_id, listing_id) → created_at` |
| `conversations` | `id`, `(listing_id, buyer_id, seller_id)` | `id → listing_id, buyer_id, seller_id, created_at, updated_at`; `(listing_id, buyer_id, seller_id) → id, created_at, updated_at` |
| `messages` | `id` | `id → conversation_id, sender_id, message_text, created_at` |
| `conversation_members` | `(conversation_id, user_id)` | `(conversation_id, user_id) → last_read_at, joined_at` |
| `lost_found_items` | `id` | `id → posted_by, item_type, title, description, location_description, image_url, date_occurred, status, created_at, updated_at` |
| `claims` | `id`, `(item_id, claimant_id)` | `id → item_id, claimant_id, claim_message, status, created_at`; `(item_id, claimant_id) → id, claim_message, status, created_at` |
| `handover_spots` | `id`, `name` | `id → name, badge, timings, description, recommended_for, location_description, latitude, longitude, is_active, created_at`; `name → id, badge, timings, description, recommended_for, location_description, latitude, longitude, is_active, created_at` |

Foreign keys such as `seller_id`, `category_id`, `conversation_id` and `claimant_id` connect relations. They do not, by themselves, create additional functional dependencies within the referencing relation.

## 8. Constraints and Data-Integrity Considerations

Normalization is supported by constraints that protect the consistency of marketplace data.

### 8.1 Primary keys and foreign keys

- Primary keys uniquely identify records.
- Foreign keys connect listings to profiles and categories, images to listings, messages to conversations and senders, and claims to lost-and-found items and claimants.
- The migration uses referential actions such as `ON DELETE CASCADE`, `ON DELETE RESTRICT` and `ON DELETE SET NULL` to control deletion behavior.

### 8.2 Unique constraints

The schema declares the following important unique constraints:

- `categories.name`
- `categories.slug`
- `(listing_id, buyer_id, seller_id)` in `conversations`
- `(item_id, claimant_id)` in `claims`
- `handover_spots.name`

These constraints establish alternate candidate keys in addition to the primary keys.

### 8.3 Check constraints

The schema also uses check constraints to enforce valid values, including:

- Non-negative listing prices.
- Allowed listing types: `sale`, `giveaway` and `exchange`.
- Allowed item conditions and listing statuses.
- A zero price for giveaway listings.
- Different buyer and seller IDs in a conversation.
- Non-empty message text.
- Allowed lost-and-found item types and statuses.
- Valid latitude and longitude ranges for handover spots.

These constraints enforce domain validity. They do not replace normalization, but they help maintain data integrity.

## 9. Practical Considerations

The schema uses separate relations for profiles, listings, categories, images, conversations, messages and other marketplace entities. This avoids repeatedly storing the same profile, category or conversation information in multiple places.

Some information is intentionally represented through relationships:

- Listing photographs are stored in `listing_images`, while the listing itself remains in `listings`.
- Saved items are represented through the `wishlists` junction relation.
- Conversation participants' read positions are stored in `conversation_members`, separately for each participant.
- Messages are stored independently and linked to their conversation.
- Claims are stored independently and linked to both the lost-and-found item and the claimant.

The supplied migration does not declare aggregate or cached columns such as a stored listing popularity count or average review rating. Such values should not be assumed to exist in this schema.

## 10. Normalization Summary

| Normal Form | Result | Explanation |
|---|---|---|
| UNF | Initial conceptual structure | Contains nested repeating groups such as listing images, messages and claims. |
| 1NF | Satisfied | Repeating groups are represented as separate rows and attributes are atomic. |
| 2NF | Satisfied | No partial dependencies exist on part of a composite candidate key. |
| 3NF | Satisfied | No transitive dependencies among non-key attributes are identified. |
| BCNF | Satisfied | Every identified non-trivial determinant is a candidate key or superkey. |

The final relational schema contains 11 relations:

1. `profiles`
2. `categories`
3. `listings`
4. `listing_images`
5. `wishlists`
6. `conversations`
7. `messages`
8. `conversation_members`
9. `lost_found_items`
10. `claims`
11. `handover_spots`

## 11. Conclusion

The Hostel OLX? student marketplace database is organized into separate relations for student profiles, categories, listings, photographs, wishlists, conversations, messages, conversation participants, lost-and-found items, claims and campus handover spots.

The relations use primary keys, foreign keys, unique constraints and check constraints to maintain data integrity. Repeating groups are represented as separate records, and composite-key relations use their complete keys to determine non-key attributes.

Based on the functional dependencies and candidate keys declared in the supplied migration, the relations satisfy 1NF, 2NF, 3NF and BCNF.

This normalized structure reduces unnecessary duplication, supports consistent updates and provides a relational foundation for the marketplace's browsing, listing, wishlist, messaging and lost-and-found features.
