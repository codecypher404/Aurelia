# Aurelia Sage Retreat — Complete Luxury Hospitality & Resort Management Ecosystem

## 1. Architecture Overview
- **Resort Location**: Madikeri, Coorg (Kodagu), Karnataka, India (`12.4209° N, 75.7397° E`, Elevation `1,170 m`).
- **43 Complete Routes**:
  - **13 Public Luxury Routes**: `/`, `/about`, `/services`, `/gallery`, `/sustainability`, `/journal`, `/table-qr`, `/book`, `/contact`, `/packages`, `/groups-events`, `/gift-cards`, `/membership`
  - **9 Personalised Guest Portal Routes**: `/my-stay`, `/my-stay/concierge`, `/my-stay/itinerary`, `/my-stay/bookings`, `/my-stay/profile`, `/my-stay/guidebook`, `/my-stay/preferences`, `/my-stay/checkout`, `/my-stay/memories`
  - **21 Resort Administration & Operations Routes**: `/admin`, `/admin/bookings`, `/admin/rooms`, `/admin/orders`, `/admin/services`, `/admin/menu`, `/admin/guests`, `/admin/analytics`, `/admin/settings`, `/admin/housekeeping`, `/admin/kitchen`, `/admin/inventory`, `/admin/maintenance`, `/admin/staff`, `/admin/revenue`, `/admin/communications`, `/admin/invoices`, `/admin/audit`, `/admin/reports`, `/admin/events`, `/admin/compliance`

## 2. Central Integration-Status Matrix
| Module / Feature | Status | Notes |
| :--- | :--- | :--- |
| 43-Route Reactive Ecosystem | **Fully Implemented** | Shared reactive store across Public, Guest Portal, KDS, Housekeeping, and Admin |
| 56-Table Supabase PostgreSQL Schema | **Fully Implemented** | `supabase/migrations/20261117000001_complete_schema.sql` with RLS & immutable audit rules |
| Genuine QR Code Generator | **Fully Implemented** | Uses client-side `qrcode` canvas rendering pointing to signed table URLs |
| Interactive 360° Virtual Tour | **Fully Implemented** | Interactive drag-pan equirectangular panorama viewer across 7 resort zones |
| Live Topographic Map (Coorg) | **Connected to Real Service** | Leaflet + Esri `World_Topo_Map` MapServer tiles centered on `12.4209° N, 75.7397° E` |
| Razorpay Checkout & Webhooks | **Simulated / Awaiting Credentials** | Server-side Edge Function ready; interactive test-mode modal clearly labelled `SIMULATED` |
| Official WhatsApp Business API | **Simulated / Awaiting Credentials** | EN/HI/KN approved templates and deep-link handoff ready |
| Channel Manager (Booking.com/Airbnb/MMT) | **Simulated / Integration-Ready** | Distinguishes iCal availability-only sync vs bidirectional Channel Manager API |
