# CP2 ER Diagram — Final Price? Student Marketplace

```mermaid
erDiagram
    PROFILES {
        uuid id PK
        varchar full_name
        varchar phone
        varchar academic_role
        varchar hostel_name
        varchar room_number
        text avatar_url
        timestamptz created_at
        timestamptz updated_at
    }
    CATEGORIES {
        uuid id PK
        varchar name UK
        varchar slug UK
    }
    LISTINGS {
        uuid id PK
        uuid seller_id FK
        uuid category_id FK
        varchar title
        text description
        numeric price
        numeric original_price
        varchar listing_type
        varchar item_condition
        varchar status
        varchar location_text
        boolean is_featured
        timestamptz created_at
        timestamptz updated_at
    }
    LISTING_IMAGES {
        uuid id PK
        uuid listing_id FK
        text image_url
        int display_order
        timestamptz created_at
    }
    WISHLISTS {
        uuid user_id PK, FK
        uuid listing_id PK, FK
        timestamptz created_at
    }
    CONVERSATIONS {
        uuid id PK
        uuid listing_id FK
        uuid buyer_id FK
        uuid seller_id FK
        timestamptz created_at
        timestamptz updated_at
    }
    MESSAGES {
        uuid id PK
        uuid conversation_id FK
        uuid sender_id FK
        text message_text
        timestamptz created_at
    }
    CONVERSATION_MEMBERS {
        uuid conversation_id PK, FK
        uuid user_id PK, FK
        timestamptz last_read_at
        timestamptz joined_at
    }
    LOST_FOUND_ITEMS {
        uuid id PK
        uuid posted_by FK
        varchar item_type
        varchar title
        text description
        varchar location_description
        text image_url
        date date_occurred
        varchar status
        timestamptz created_at
        timestamptz updated_at
    }
    CLAIMS {
        uuid id PK
        uuid item_id FK
        uuid claimant_id FK
        text claim_message
        varchar status
        timestamptz created_at
    }
    HANDOVER_SPOTS {
        uuid id PK
        varchar name UK
        varchar badge
        varchar timings
        text description
        text recommended_for
        text location_description
        numeric latitude
        numeric longitude
        boolean is_active
        timestamptz created_at
    }
    PROFILES ||--o{ LISTINGS : publishes
    CATEGORIES ||--o{ LISTINGS : classifies
    LISTINGS ||--o{ LISTING_IMAGES : has
    PROFILES ||--o{ WISHLISTS : saves
    LISTINGS ||--o{ WISHLISTS : is_saved_in
    LISTINGS ||--o{ CONVERSATIONS : concerns
    PROFILES ||--o{ CONVERSATIONS : buyer
    PROFILES ||--o{ CONVERSATIONS : seller
    CONVERSATIONS ||--o{ MESSAGES : contains
    PROFILES ||--o{ MESSAGES : sends
    CONVERSATIONS ||--o{ CONVERSATION_MEMBERS : has_members
    PROFILES ||--o{ CONVERSATION_MEMBERS : participates
    PROFILES ||--o{ LOST_FOUND_ITEMS : posts
    LOST_FOUND_ITEMS ||--o{ CLAIMS : receives
    PROFILES ||--o{ CLAIMS : submits
```

## Relationship notes

- A profile can publish many listings; each listing has one seller and one category.
- A listing can have multiple images and can be saved by many profiles through `wishlists`.
- A listing can have buyer/seller conversations; each conversation contains messages.
- `conversation_members` records each participant and their read state.
- A profile can post lost-and-found reports; each report can receive claims.
- Handover spots are independent campus locations.
- `wishlists` and `conversation_members` use composite primary keys.
- `categories`, `conversations`, `claims`, and `handover_spots` include alternate unique keys documented in CP1.
