# 🚗 CarDecide - Intelligent Automotive Decision Platform

CarDecide is a comprehensive mobile application developed with **Flutter** and **Supabase**, designed to empower Malaysian car buyers with data-driven decision-making tools. The platform uniquely integrates **Multimodal Generative AI (Google Gemini)**, **Hardware Sensors (Camera & GPS)**, and **Live Open Government Data**.

---

## 🌟 Key Modules & Features

### 📸 1. AI Vision & Dynamic Vehicle Intelligence (Tan Ea Son)
- **Snap & Identify**: Utilises device **Camera & Image Picker** with **Gemini 1.5 Flash** to identify car models from live photos.
- **Dynamic Database Auto-Population**: New vehicles analyzed by AI are automatically validated and written to the Supabase database with deduplication checks.
- **Smart Input Validation**: Intelligent rejection for non-automotive inputs to preserve data integrity.
- **Hero Transitions**: Smooth, native shared element animations for vehicle browsing and detail view.

### 🗺️ 2. Geospatial Dealerships & Transit Economics (Pang Zheng Yuan)
- **Live Dealership Map**: Harnesses device **GPS Location** (`geolocator`) and **OpenStreetMap (OSM)** to locate nearby car showrooms without commercial API costs.
- **Transit vs. Driving Comparator**: Comparative cost analysis engine matching driving expenses (tolls, parking, fuel) against public transit (LRT/MRT/Monorail).
- **Live Fuel Prices**: Real-time weekly Malaysian fuel pricing integrated via **data.gov.my** open API with local caching.

### 👤 3. Secure Cloud Identity & Car Advisory (Jan Man Sing)
- **Supabase Authentication**: Secure Email/Password registration, password reset, and frictionless **Guest Mode**.
- **User Profile & Storage**: Remote avatar uploads powered by Supabase Cloud Storage with camera/gallery options.
- **Saved Cars (Favourites)**: Personalised vehicle bookmarks protected by PostgreSQL **Row-Level Security (RLS)**.
- **AI Automotive Advisor**: Context-aware interactive chatbot providing customized buying advice with offline error resilience.

---

## 🛠️ Tech Stack & Architecture
- **Framework**: Flutter (Dart)
- **Backend & Auth**: Supabase (PostgreSQL, Row-Level Security, Storage)
- **AI Engine**: Google Gemini 1.5 Flash (Multimodal)
- **Mapping & Geocoding**: `flutter_map`, OpenStreetMap, Nominatim API
- **Hardware Integration**: Device Camera, GPS Geolocation
- **Security**: `.env` credential isolation with `flutter_dotenv`

---

## 👥 Project Team (TAR UMT)
- **Tan Ea Son** - Lead Developer (AI Multimodal Vision, Auto-Populating DB, Car Inventory)
- **Pang Zheng Yuan** - Core Developer (Geospatial Mapping, LBS, Transit Cost Engine)
- **Jan Man Sing** - Core Developer (Authentication, Cloud Storage, AI Advisor)

