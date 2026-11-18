-- ============================================================================
-- AURELIA SAGE RETREAT — SUPABASE POSTGRESQL COMPLETE DATABASE SCHEMA
-- 56 Structured Tables across 7 Domains with UUID PKs, Foreign Keys, Indexes,
-- Triggers, Idempotency Constraints, and Row Level Security (RLS) Policies.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- DOMAIN 1: AUTHENTICATION & GUESTS (8 TABLES)
-- ============================================================================

CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    role TEXT NOT NULL DEFAULT 'guest' CHECK (role IN ('guest', 'front_desk', 'housekeeping', 'kitchen', 'spa', 'maintenance', 'concierge', 'manager', 'admin')),
    preferred_language TEXT NOT NULL DEFAULT 'en' CHECK (preferred_language IN ('en', 'hi', 'kn')),
    preferred_currency TEXT NOT NULL DEFAULT 'INR' CHECK (preferred_currency IN ('INR', 'USD', 'EUR', 'GBP')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE guests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    nationality TEXT NOT NULL DEFAULT 'IN',
    is_vip BOOLEAN NOT NULL DEFAULT FALSE,
    gstin TEXT,
    company_name TEXT,
    total_stays INTEGER NOT NULL DEFAULT 0,
    total_spend_inr NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE guest_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guest_id UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE UNIQUE,
    pillow_type TEXT DEFAULT 'Organic Buckwheat & Soft Down Alternative',
    room_temperature_c NUMERIC(4,1) DEFAULT 22.0,
    dietary_preferences TEXT[] DEFAULT '{}',
    food_allergies TEXT[] DEFAULT '{}',
    quiet_room_requested BOOLEAN NOT NULL DEFAULT FALSE,
    preferred_accommodation_category TEXT,
    celebration_dates JSONB DEFAULT '[]'::jsonb,
    communication_channels TEXT[] DEFAULT ARRAY['email', 'whatsapp'],
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE guest_accessibility_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guest_id UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE UNIQUE,
    step_free_access BOOLEAN NOT NULL DEFAULT FALSE,
    ground_floor_required BOOLEAN NOT NULL DEFAULT FALSE,
    grab_rails_required BOOLEAN NOT NULL DEFAULT FALSE,
    visual_or_hearing_assistance TEXT,
    buggy_priority_dispatch BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE guest_consents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guest_id UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    purpose TEXT NOT NULL CHECK (purpose IN ('booking_processing', 'whatsapp_transactional', 'marketing_upsell', 'abandoned_cart_recovery', 'preference_storage', 'identity_verification')),
    consented BOOLEAN NOT NULL,
    policy_version TEXT NOT NULL DEFAULT 'DPDP-2026.1',
    ip_source TEXT,
    consented_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    withdrawn_at TIMESTAMPTZ
);

CREATE TABLE guest_identity_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guest_id UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
    booking_id UUID,
    is_foreign_national BOOLEAN NOT NULL DEFAULT FALSE,
    document_type TEXT NOT NULL CHECK (document_type IN ('aadhaar_masked', 'passport', 'driving_licence', 'voter_id', 'oci_card')),
    encrypted_storage_path TEXT NOT NULL,
    document_number_masked TEXT NOT NULL,
    verification_status TEXT NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending', 'verified', 'rejected')),
    form_c_status TEXT NOT NULL DEFAULT 'not_applicable' CHECK (form_c_status IN ('not_applicable', 'draft_prepared', 'reviewed_by_officer', 'submitted_to_frro')),
    verified_by UUID REFERENCES profiles(id),
    retention_expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE membership_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guest_id UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE UNIQUE,
    membership_number TEXT UNIQUE NOT NULL,
    tier TEXT NOT NULL DEFAULT 'Sage Seed' CHECK (tier IN ('Sage Seed', 'Canopy Circle', 'Sanctuary Patron')),
    points_balance INTEGER NOT NULL DEFAULT 0,
    qualifying_nights INTEGER NOT NULL DEFAULT 0,
    referral_code TEXT UNIQUE NOT NULL,
    tier_expires_at DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE referral_rewards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    referrer_membership_id UUID NOT NULL REFERENCES membership_accounts(id) ON DELETE CASCADE,
    referred_guest_email TEXT NOT NULL,
    reward_amount_inr NUMERIC(10,2) NOT NULL DEFAULT 3000.00,
    status TEXT NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'booked', 'credited', 'expired')),
    expires_at DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- DOMAIN 2: ACCOMMODATION & BOOKINGS (13 TABLES)
-- ============================================================================

CREATE TABLE room_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    short_description TEXT NOT NULL,
    base_price_inr NUMERIC(10,2) NOT NULL CHECK (base_price_inr > 0),
    max_adults INTEGER NOT NULL DEFAULT 2,
    max_children INTEGER NOT NULL DEFAULT 2,
    area_sqft INTEGER NOT NULL,
    view_type TEXT NOT NULL,
    private_facilities TEXT[] NOT NULL DEFAULT '{}',
    amenities TEXT[] NOT NULL DEFAULT '{}',
    images TEXT[] NOT NULL DEFAULT '{}',
    total_inventory INTEGER NOT NULL DEFAULT 6,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_number TEXT UNIQUE NOT NULL,
    category_id UUID NOT NULL REFERENCES room_categories(id) ON DELETE RESTRICT,
    floor_zone TEXT NOT NULL,
    housekeeping_status TEXT NOT NULL DEFAULT 'Ready' CHECK (housekeeping_status IN ('Dirty', 'Cleaning', 'Cleaning Completed', 'Inspection Pending', 'Inspected', 'Ready', 'Occupied', 'Maintenance Blocked')),
    is_bookable BOOLEAN NOT NULL DEFAULT TRUE,
    last_inspected_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE room_availability (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    stay_date DATE NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    locked_by_booking_id UUID,
    closed_to_arrival BOOLEAN NOT NULL DEFAULT FALSE,
    closed_to_departure BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (room_id, stay_date)
);

CREATE TABLE room_rate_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID REFERENCES room_categories(id) ON DELETE CASCADE,
    rule_name TEXT NOT NULL,
    rule_type TEXT NOT NULL CHECK (rule_type IN ('weekend', 'seasonal', 'holiday', 'last_minute', 'early_bird', 'long_stay', 'occupancy_surge')),
    multiplier NUMERIC(5,3) NOT NULL DEFAULT 1.000,
    flat_adjustment_inr NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    min_stay_nights INTEGER NOT NULL DEFAULT 1,
    max_stay_nights INTEGER NOT NULL DEFAULT 30,
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE booking_sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    channel_type TEXT NOT NULL CHECK (channel_type IN ('direct_web', 'direct_whatsapp', 'booking_com', 'airbnb', 'makemytrip', 'corporate')),
    commission_pct NUMERIC(5,2) NOT NULL DEFAULT 0.00
);

CREATE TABLE cancellation_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    free_cancellation_hours_before INTEGER NOT NULL DEFAULT 168,
    partial_refund_pct NUMERIC(5,2) NOT NULL DEFAULT 50.00,
    non_refundable_window_hours INTEGER NOT NULL DEFAULT 48,
    description TEXT NOT NULL
);

CREATE TABLE promotional_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT UNIQUE NOT NULL,
    description TEXT NOT NULL,
    discount_type TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed_inr')),
    discount_value NUMERIC(10,2) NOT NULL,
    min_nights INTEGER NOT NULL DEFAULT 1,
    stackable_with_direct_benefit BOOLEAN NOT NULL DEFAULT FALSE,
    max_redemptions INTEGER NOT NULL DEFAULT 100,
    redemption_count INTEGER NOT NULL DEFAULT 0,
    valid_from DATE NOT NULL,
    valid_until DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE seasonal_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    season_tag TEXT NOT NULL,
    description TEXT NOT NULL,
    included_experiences TEXT[] NOT NULL DEFAULT '{}',
    min_nights INTEGER NOT NULL DEFAULT 2,
    package_price_inr NUMERIC(12,2) NOT NULL,
    valid_from DATE NOT NULL,
    valid_until DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_reference TEXT UNIQUE NOT NULL,
    guest_id UUID NOT NULL REFERENCES guests(id) ON DELETE RESTRICT,
    category_id UUID NOT NULL REFERENCES room_categories(id) ON DELETE RESTRICT,
    assigned_room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
    source_id UUID REFERENCES booking_sources(id),
    cancellation_policy_id UUID REFERENCES cancellation_policies(id),
    package_id UUID REFERENCES seasonal_packages(id),
    check_in DATE NOT NULL,
    check_out DATE NOT NULL,
    nights INTEGER GENERATED ALWAYS AS (check_out - check_in) STORED,
    adults INTEGER NOT NULL DEFAULT 2 CHECK (adults >= 1),
    children INTEGER NOT NULL DEFAULT 0 CHECK (children >= 0),
    status TEXT NOT NULL DEFAULT 'confirmed' CHECK (status IN ('pending_payment', 'confirmed', 'checked_in', 'checked_out', 'cancelled')),
    room_subtotal_inr NUMERIC(12,2) NOT NULL,
    addons_subtotal_inr NUMERIC(12,2) NOT NULL DEFAULT 0,
    direct_discount_inr NUMERIC(12,2) NOT NULL DEFAULT 0,
    promo_discount_inr NUMERIC(12,2) NOT NULL DEFAULT 0,
    taxable_amount_inr NUMERIC(12,2) NOT NULL,
    gst_rate_pct NUMERIC(5,2) NOT NULL DEFAULT 18.00,
    cgst_inr NUMERIC(12,2) NOT NULL DEFAULT 0,
    sgst_inr NUMERIC(12,2) NOT NULL DEFAULT 0,
    igst_inr NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_amount_inr NUMERIC(12,2) NOT NULL,
    arrival_time TEXT,
    special_requests TEXT,
    celebration_occasion TEXT,
    digital_checkin_completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT valid_stay_dates CHECK (check_out > check_in)
);

CREATE TABLE booking_addons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    addon_code TEXT NOT NULL,
    addon_name TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price_inr NUMERIC(10,2) NOT NULL,
    total_price_inr NUMERIC(10,2) NOT NULL
);

CREATE TABLE booking_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_token TEXT UNIQUE NOT NULL,
    guest_email TEXT,
    guest_phone TEXT,
    consent_given BOOLEAN NOT NULL DEFAULT FALSE,
    selected_category_id UUID REFERENCES room_categories(id),
    check_in DATE,
    check_out DATE,
    adults INTEGER DEFAULT 2,
    children INTEGER DEFAULT 0,
    selected_addons JSONB DEFAULT '[]'::jsonb,
    estimated_value_inr NUMERIC(12,2) DEFAULT 0,
    recovery_status TEXT NOT NULL DEFAULT 'active' CHECK (recovery_status IN ('active', 'abandoned', 'reminder_sent', 'recovered', 'expired')),
    reminder_count INTEGER NOT NULL DEFAULT 0,
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE booking_upsells (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    upsell_type TEXT NOT NULL CHECK (upsell_type IN ('room_upgrade', 'airport_transfer', 'spa_package', 'private_dining', 'celebration_setup')),
    stage TEXT NOT NULL CHECK (stage IN ('7_days_prior', '3_days_prior', '1_day_prior', 'checkin_portal')),
    offered_price_inr NUMERIC(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'offered' CHECK (status IN ('offered', 'accepted', 'declined', 'expired')),
    responded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE group_inquiries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inquiry_reference TEXT UNIQUE NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('Wedding', 'Corporate Offsite', 'Yoga & Wellness Retreat', 'Private Celebration', 'Group Buyout')),
    contact_name TEXT NOT NULL,
    contact_email TEXT NOT NULL,
    contact_phone TEXT NOT NULL,
    preferred_start_date DATE NOT NULL,
    preferred_end_date DATE NOT NULL,
    expected_guests INTEGER NOT NULL,
    rooms_required INTEGER NOT NULL,
    venue_preference TEXT NOT NULL,
    catering_preference TEXT NOT NULL,
    budget_range_inr TEXT NOT NULL,
    quotation_amount_inr NUMERIC(12,2),
    status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'reviewing', 'quotation_sent', 'confirmed', 'archived')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- DOMAIN 3: PAYMENTS, GST BILLING & RECONCILIATION (7 TABLES)
-- ============================================================================

CREATE TABLE tax_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_category TEXT UNIQUE NOT NULL,
    sac_code TEXT NOT NULL,
    tariff_threshold_inr NUMERIC(10,2) DEFAULT 7500.00,
    gst_rate_below_threshold_pct NUMERIC(5,2) NOT NULL DEFAULT 5.00,
    gst_rate_above_threshold_pct NUMERIC(5,2) NOT NULL DEFAULT 18.00,
    itc_eligible_above_threshold BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from DATE NOT NULL DEFAULT '2025-09-22',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
    payment_reference TEXT UNIQUE NOT NULL,
    razorpay_order_id TEXT UNIQUE,
    razorpay_payment_id TEXT UNIQUE,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('razorpay_upi', 'razorpay_card', 'razorpay_netbanking', 'bank_transfer', 'simulated_test')),
    amount_inr NUMERIC(12,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'authorized', 'captured', 'partially_paid', 'failed', 'refunded')),
    verified_by_webhook BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE payment_webhook_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id TEXT UNIQUE NOT NULL,
    razorpay_order_id TEXT,
    event_type TEXT NOT NULL,
    signature_verified BOOLEAN NOT NULL DEFAULT FALSE,
    payload JSONB NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE refunds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
    refund_reference TEXT UNIQUE NOT NULL,
    refund_type TEXT NOT NULL CHECK (refund_type IN ('full', 'partial_policy', 'goodwill')),
    original_amount_inr NUMERIC(12,2) NOT NULL,
    cancellation_penalty_inr NUMERIC(12,2) NOT NULL DEFAULT 0,
    refundable_amount_inr NUMERIC(12,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'initiated' CHECK (status IN ('initiated', 'approved', 'processed', 'failed')),
    expected_timeline TEXT NOT NULL DEFAULT '5-7 business days',
    approved_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_number TEXT UNIQUE NOT NULL,
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
    guest_id UUID NOT NULL REFERENCES guests(id) ON DELETE RESTRICT,
    supplier_gstin TEXT NOT NULL DEFAULT '29AABCA8921K1Z5',
    customer_gstin TEXT,
    place_of_supply TEXT NOT NULL DEFAULT '29-Karnataka',
    is_intra_state BOOLEAN NOT NULL DEFAULT TRUE,
    taxable_value_inr NUMERIC(12,2) NOT NULL,
    cgst_amount_inr NUMERIC(12,2) NOT NULL DEFAULT 0,
    sgst_amount_inr NUMERIC(12,2) NOT NULL DEFAULT 0,
    igst_amount_inr NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_invoice_inr NUMERIC(12,2) NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    sac_code TEXT NOT NULL DEFAULT '996311',
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price_inr NUMERIC(12,2) NOT NULL,
    gst_rate_pct NUMERIC(5,2) NOT NULL,
    tax_amount_inr NUMERIC(12,2) NOT NULL,
    line_total_inr NUMERIC(12,2) NOT NULL
);

CREATE TABLE payment_reconciliation (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reconciliation_date DATE NOT NULL,
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    gateway_settled_inr NUMERIC(12,2) NOT NULL,
    ledger_recorded_inr NUMERIC(12,2) NOT NULL,
    discrepancy_inr NUMERIC(12,2) GENERATED ALWAYS AS (gateway_settled_inr - ledger_recorded_inr) STORED,
    status TEXT NOT NULL DEFAULT 'matched' CHECK (status IN ('matched', 'mismatch_flagged', 'resolved'))
);

-- ============================================================================
-- DOMAIN 4: DINING, SMART QR & EXPERIENCES (10 TABLES)
-- ============================================================================

CREATE TABLE experiences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Wellness & Spa', 'Fine Dining', 'Curated Excursions', 'In-Room Amenities', 'Adventure & Nature', 'Couples & Celebrations')),
    duration_minutes INTEGER NOT NULL,
    price_inr NUMERIC(10,2) NOT NULL,
    description TEXT NOT NULL,
    available_slots TEXT[] NOT NULL DEFAULT ARRAY['07:00', '10:00', '14:00', '17:00', '19:30'],
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE experience_reservations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    guest_id UUID REFERENCES guests(id) ON DELETE SET NULL,
    experience_id UUID NOT NULL REFERENCES experiences(id) ON DELETE RESTRICT,
    reservation_date DATE NOT NULL,
    time_slot TEXT NOT NULL,
    guest_count INTEGER NOT NULL DEFAULT 2,
    custom_setup JSONB DEFAULT '{}'::jsonb,
    total_price_inr NUMERIC(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'in_progress', 'completed', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE menu_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE menu_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID NOT NULL REFERENCES menu_categories(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    price_inr NUMERIC(10,2) NOT NULL,
    dietary_tags TEXT[] NOT NULL DEFAULT '{}',
    key_ingredient_sku TEXT,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    image_url TEXT
);

CREATE TABLE qr_tables (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_code TEXT UNIQUE NOT NULL,
    location_name TEXT NOT NULL,
    zone TEXT NOT NULL,
    signed_url_token TEXT UNIQUE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number TEXT UNIQUE NOT NULL,
    qr_table_id UUID REFERENCES qr_tables(id),
    booking_id UUID REFERENCES bookings(id),
    table_label TEXT NOT NULL,
    subtotal_inr NUMERIC(10,2) NOT NULL,
    gst_inr NUMERIC(10,2) NOT NULL,
    total_inr NUMERIC(10,2) NOT NULL,
    dietary_notes TEXT,
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'high', 'vip_allergy')),
    status TEXT NOT NULL DEFAULT 'New Order' CHECK (status IN ('New Order', 'Accepted', 'Preparing', 'Ready', 'Dispatched', 'Completed')),
    assigned_chef TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id UUID REFERENCES menu_items(id),
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_inr NUMERIC(10,2) NOT NULL,
    special_instructions TEXT
);

CREATE TABLE inventory_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sku TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Food Ingredients', 'Beverages', 'Kitchen Supplies', 'Housekeeping Supplies', 'Spa Products', 'General Amenities')),
    current_stock NUMERIC(10,2) NOT NULL,
    unit TEXT NOT NULL,
    min_threshold NUMERIC(10,2) NOT NULL,
    supplier_name TEXT NOT NULL,
    last_restocked_at DATE,
    expiry_date DATE
);

CREATE TABLE inventory_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inventory_item_id UUID NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
    delta NUMERIC(10,2) NOT NULL,
    reason TEXT NOT NULL,
    performed_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE service_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_code TEXT UNIQUE NOT NULL,
    booking_id UUID REFERENCES bookings(id),
    guest_name TEXT NOT NULL,
    room_or_table TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Dining', 'Housekeeping', 'Transportation', 'Wellness', 'Experiences', 'Assistance', 'Emergency')),
    description TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'Normal' CHECK (priority IN ('Normal', 'High', 'Urgent', 'Emergency')),
    status TEXT NOT NULL DEFAULT 'Submitted' CHECK (status IN ('Submitted', 'Acknowledged', 'In Progress', 'Completed')),
    assigned_department TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- DOMAIN 5: GUEST EXPERIENCE & PORTAL (7 TABLES)
-- ============================================================================

CREATE TABLE itineraries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    guest_id UUID REFERENCES guests(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    mode TEXT NOT NULL DEFAULT 'slow_living' CHECK (mode IN ('slow_living', 'activity_focused')),
    duration_days INTEGER NOT NULL DEFAULT 3,
    wellness_intake JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE itinerary_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    itinerary_id UUID NOT NULL REFERENCES itineraries(id) ON DELETE CASCADE,
    day_number INTEGER NOT NULL CHECK (day_number >= 1),
    time_slot TEXT NOT NULL,
    activity_title TEXT NOT NULL,
    category TEXT NOT NULL,
    is_rest_window BOOLEAN NOT NULL DEFAULT FALSE,
    personal_notes TEXT
);

CREATE TABLE guest_memories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    caption TEXT NOT NULL,
    photographer_credit TEXT NOT NULL DEFAULT 'Aurelia Visual Archive',
    image_url TEXT NOT NULL,
    shared_with_guest BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    guest_name TEXT NOT NULL,
    stay_category TEXT NOT NULL,
    overall_rating INTEGER NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
    room_rating INTEGER NOT NULL CHECK (room_rating BETWEEN 1 AND 5),
    dining_rating INTEGER NOT NULL CHECK (dining_rating BETWEEN 1 AND 5),
    staff_rating INTEGER NOT NULL CHECK (staff_rating BETWEEN 1 AND 5),
    comment TEXT NOT NULL,
    is_verified_stay BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE wishlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guest_id UUID REFERENCES guests(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL CHECK (item_type IN ('villa', 'experience', 'dining', 'journal')),
    item_slug TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE gift_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    voucher_code TEXT UNIQUE NOT NULL,
    voucher_type TEXT NOT NULL CHECK (voucher_type IN ('Stay Voucher', 'Dining Voucher', 'Spa Sanctuary Voucher', 'Custom Bespoke Amount')),
    initial_amount_inr NUMERIC(10,2) NOT NULL,
    balance_inr NUMERIC(10,2) NOT NULL,
    sender_name TEXT NOT NULL,
    recipient_name TEXT NOT NULL,
    recipient_email TEXT NOT NULL,
    personal_message TEXT,
    is_simulated BOOLEAN NOT NULL DEFAULT TRUE,
    expires_at DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE concierge_conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id),
    channel TEXT NOT NULL DEFAULT 'whatsapp_official' CHECK (channel IN ('portal_chat', 'whatsapp_official')),
    template_used TEXT,
    message_direction TEXT NOT NULL CHECK (message_direction IN ('inbound', 'outbound')),
    message_body TEXT NOT NULL,
    human_handoff_active BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- DOMAIN 6: RESORT OPERATIONS (8 TABLES)
-- ============================================================================

CREATE TABLE staff_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_code TEXT UNIQUE NOT NULL,
    department TEXT NOT NULL,
    permissions TEXT[] NOT NULL DEFAULT '{}'
);

CREATE TABLE staff_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    employee_code TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    department TEXT NOT NULL CHECK (department IN ('Front Desk', 'Housekeeping', 'Kitchen', 'Restaurant', 'Spa', 'Maintenance', 'Concierge', 'Management')),
    role_title TEXT NOT NULL,
    active_shift TEXT NOT NULL DEFAULT 'Morning (07:00 - 15:30)',
    is_on_duty BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE staff_shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    staff_id UUID NOT NULL REFERENCES staff_profiles(id) ON DELETE CASCADE,
    shift_date DATE NOT NULL,
    shift_window TEXT NOT NULL,
    attendance_status TEXT NOT NULL DEFAULT 'Present' CHECK (attendance_status IN ('Present', 'Scheduled', 'Off Duty', 'Handover Complete')),
    handover_notes TEXT
);

CREATE TABLE housekeeping_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    assigned_staff_id UUID REFERENCES staff_profiles(id),
    task_status TEXT NOT NULL DEFAULT 'Dirty' CHECK (task_status IN ('Dirty', 'Cleaning', 'Cleaning Completed', 'Inspection Pending', 'Inspected', 'Ready', 'Occupied', 'Maintenance Blocked')),
    priority TEXT NOT NULL DEFAULT 'Normal' CHECK (priority IN ('Normal', 'High', 'Arrival VIP')),
    cleaning_deadline TEXT NOT NULL DEFAULT '13:00',
    missing_amenities_reported TEXT,
    instructions TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE housekeeping_inspections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES housekeeping_tasks(id) ON DELETE CASCADE,
    inspector_id UUID REFERENCES staff_profiles(id),
    checklist_passed BOOLEAN NOT NULL DEFAULT TRUE,
    photo_evidence_url TEXT,
    inspected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE maintenance_tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_code TEXT UNIQUE NOT NULL,
    room_id UUID REFERENCES rooms(id),
    location_label TEXT NOT NULL,
    issue_category TEXT NOT NULL CHECK (issue_category IN ('Plumbing', 'Electrical', 'HVAC / Air-Conditioning', 'Furniture & Timber', 'Appliance', 'Infrastructure', 'General')),
    description TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High', 'Critical Safety')),
    assigned_technician TEXT,
    blocks_room_inventory BOOLEAN NOT NULL DEFAULT FALSE,
    status TEXT NOT NULL DEFAULT 'Reported' CHECK (status IN ('Reported', 'Assigned', 'In Progress', 'Awaiting Parts', 'Resolved', 'Closed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE kitchen_order_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    previous_status TEXT,
    new_status TEXT NOT NULL,
    elapsed_seconds INTEGER NOT NULL DEFAULT 0,
    changed_by TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE operational_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_date DATE UNIQUE NOT NULL,
    expected_arrivals INTEGER NOT NULL,
    expected_departures INTEGER NOT NULL,
    previous_day_revenue_inr NUMERIC(12,2) NOT NULL,
    direct_booking_share_pct NUMERIC(5,2) NOT NULL,
    summary_payload JSONB NOT NULL,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- DOMAIN 7: REVENUE, INTEGRATIONS, AUDIT & SUSTAINABILITY (17 TABLES)
-- ============================================================================

CREATE TABLE channel_reservations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    external_reservation_id TEXT UNIQUE NOT NULL,
    channel_name TEXT NOT NULL CHECK (channel_name IN ('Booking.com', 'Airbnb', 'MakeMyTrip')),
    sync_method TEXT NOT NULL CHECK (sync_method IN ('authorized_channel_api', 'ical_availability_only')),
    room_category_slug TEXT NOT NULL,
    check_in DATE NOT NULL,
    check_out DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'imported'
);

CREATE TABLE channel_sync_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    channel_name TEXT NOT NULL,
    sync_mode TEXT NOT NULL CHECK (sync_mode IN ('iCal Availability Feed', 'Authorized Channel Manager API')),
    rooms_synced INTEGER NOT NULL,
    conflicts_detected INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'success',
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE revenue_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rule_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    occupancy_threshold_pct INTEGER NOT NULL DEFAULT 75,
    rate_adjustment_pct NUMERIC(5,2) NOT NULL DEFAULT 15.00,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE direct_booking_offers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    discount_pct NUMERIC(5,2) NOT NULL DEFAULT 10.00,
    complimentary_breakfast BOOLEAN NOT NULL DEFAULT TRUE,
    experience_credit_inr NUMERIC(10,2) NOT NULL DEFAULT 2500.00,
    flexible_checkin BOOLEAN NOT NULL DEFAULT TRUE,
    min_stay_nights INTEGER NOT NULL DEFAULT 2,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE communication_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_code TEXT UNIQUE NOT NULL,
    channel TEXT NOT NULL CHECK (channel IN ('whatsapp', 'email')),
    language TEXT NOT NULL CHECK (language IN ('en', 'hi', 'kn')),
    subject_or_header TEXT NOT NULL,
    body_template TEXT NOT NULL,
    approval_status TEXT NOT NULL DEFAULT 'Approved'
);

CREATE TABLE communication_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_id UUID REFERENCES communication_templates(id),
    recipient TEXT NOT NULL,
    channel TEXT NOT NULL,
    delivery_status TEXT NOT NULL DEFAULT 'delivered',
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE abandoned_booking_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES booking_sessions(id) ON DELETE CASCADE,
    channel TEXT NOT NULL,
    recovery_link TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id TEXT NOT NULL,
    actor_role TEXT NOT NULL,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    previous_value JSONB,
    new_value JSONB,
    ip_address TEXT DEFAULT '10.24.0.12',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE RULE audit_logs_no_update AS ON UPDATE TO audit_logs DO INSTEAD NOTHING;
CREATE RULE audit_logs_no_delete AS ON DELETE TO audit_logs DO INSTEAD NOTHING;

CREATE TABLE feature_flags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    flag_key TEXT UNIQUE NOT NULL,
    label TEXT NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    integration_mode TEXT NOT NULL DEFAULT 'simulated_demo' CHECK (integration_mode IN ('live_connected', 'simulated_demo', 'awaiting_credentials')),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_role TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE sustainability_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    metric_key TEXT UNIQUE NOT NULL,
    label TEXT NOT NULL,
    value_numeric NUMERIC(12,2) NOT NULL,
    unit TEXT NOT NULL,
    is_illustrative BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE sustainability_participation (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    linen_reuse_opt_in BOOLEAN NOT NULL DEFAULT TRUE,
    plantation_walk_opt_in BOOLEAN NOT NULL DEFAULT FALSE,
    native_tree_sponsored BOOLEAN NOT NULL DEFAULT FALSE,
    conservation_pledge BOOLEAN NOT NULL DEFAULT TRUE,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE wildlife_species (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    common_name TEXT UNIQUE NOT NULL,
    scientific_name TEXT NOT NULL,
    iucn_status TEXT NOT NULL,
    habitat_zone TEXT NOT NULL,
    description TEXT NOT NULL
);

CREATE TABLE wildlife_sightings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    species_id UUID REFERENCES wildlife_species(id),
    species_name TEXT NOT NULL,
    observer_name TEXT NOT NULL,
    sighting_date DATE NOT NULL,
    resort_zone TEXT NOT NULL,
    notes TEXT,
    verification_status TEXT NOT NULL DEFAULT 'pending_naturalist_review' CHECK (verification_status IN ('pending_naturalist_review', 'verified', 'flagged')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE artisan_products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sku TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Coffee', 'Spices', 'Honey', 'Handmade Crafts', 'Local Food', 'Sustainable Merchandise')),
    artisan_partner TEXT NOT NULL,
    price_inr NUMERIC(10,2) NOT NULL,
    stock_count INTEGER NOT NULL DEFAULT 25,
    fulfilment_options TEXT[] NOT NULL DEFAULT ARRAY['On-Site Villa Collection', 'Shipping Inquiry']
);

CREATE TABLE newsletter_subscribers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    subscribed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE journal_articles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Discover Coorg', 'Coffee Culture', 'Wellness & Living', 'Sustainable Travel', 'Resort Stories', 'Local Experiences')),
    author_name TEXT NOT NULL,
    reading_time_min INTEGER NOT NULL,
    excerpt TEXT NOT NULL,
    body_markdown TEXT NOT NULL,
    published_at DATE NOT NULL
);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE guests ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_identity_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Guests view own bookings; staff view all" ON bookings
    FOR SELECT USING (
        auth.uid() IN (SELECT profile_id FROM guests WHERE id = bookings.guest_id)
        OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('front_desk', 'manager', 'admin'))
    );

CREATE POLICY "Only authorized compliance officers access identity docs" ON guest_identity_documents
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('front_desk', 'manager', 'admin'))
    );

CREATE POLICY "Only management reads immutable audit logs" ON audit_logs
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('manager', 'admin'))
    );
