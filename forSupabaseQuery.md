-- ==============================================================================
-- DOKUMENTASI & SKEMA SUPABASE POSTGRESQL (ARSITEKTUR BARU - NEW_DB)
-- LEVMAX: Solo Leveling Lifestyle RPG Mobile Application
--
-- Karakteristik Utama:
-- 1. Seluruh Primary Key (PK) & Foreign Key (FK) menggunakan tipe UUID (gen_random_uuid())
-- 2. Penambahan 4 Pilar Atribut RPG: str, agi, "int" (int_stat), dan cha
-- 3. Penambahan Data Fisik Onboarding: height, weight, dan bmi_score
-- 4. Pemisahan Relasional Quests: master_quests (Master) & daily_user_quests (Transaksi)
-- 5. Tabel item_shop & blockchain_inventory_logs untuk Notarisasi SHA-256
-- 6. Disable Row Level Security (RLS) untuk kemudahan akses HTTP REST API
-- ==============================================================================

-- Aktifkan ekstensi pgcrypto untuk fungsi gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 1. TABEL: users (Profil Hunter, Atribut RPG, & Metrik Fisik)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    biometric_enabled BOOLEAN DEFAULT FALSE,
    is_onboarded BOOLEAN DEFAULT FALSE,
    
    -- Metrik Antropometri & Kalibrasi Fisik
    height INT DEFAULT 170,                       -- Tinggi badan dalam cm
    weight DOUBLE PRECISION DEFAULT 65.0,         -- Berat badan dalam kg
    bmi_score DOUBLE PRECISION DEFAULT 22.49,     -- Nilai Indeks Massa Tubuh
    tb_cm DOUBLE PRECISION DEFAULT 170.0,         -- Alias kompatibilitas
    bb_kg DOUBLE PRECISION DEFAULT 65.0,          -- Alias kompatibilitas
    bmi DOUBLE PRECISION DEFAULT 22.49,           -- Alias kompatibilitas
    
    -- Hasil Uji Kalibrasi 1 Menit
    max_pushup INT DEFAULT 10,
    max_situp INT DEFAULT 10,
    max_squat INT DEFAULT 10,
    max_pullup INT DEFAULT 5,
    max_run_km DOUBLE PRECISION DEFAULT 2.0,
    pace_2km_menit DOUBLE PRECISION DEFAULT 15.0,
    
    -- Status Gamifikasi Solo Leveling (Status Window)
    level INT DEFAULT 1 CHECK (level >= 1),
    rank VARCHAR(5) DEFAULT 'F' CHECK (rank IN ('F', 'E', 'D', 'C', 'B', 'A', 'S')),
    hp INT DEFAULT 100 CHECK (hp >= 0 AND hp <= 100),
    exp INT DEFAULT 0 CHECK (exp >= 0),
    gold INT DEFAULT 0 CHECK (gold >= 0),
    
    -- 4 Pilar Atribut RPG Utama
    str INT DEFAULT 10 CHECK (str >= 0),
    agi INT DEFAULT 10 CHECK (agi >= 0),
    "int" INT DEFAULT 10 CHECK ("int" >= 0),      -- Kolom resmi "int"
    int_stat INT DEFAULT 10 CHECK (int_stat >= 0),-- Alias int_stat
    cha INT DEFAULT 10 CHECK (cha >= 0),
    
    -- Status Penalti & Tracking Aktivitas
    is_penalty_active BOOLEAN DEFAULT FALSE,
    last_active_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==============================================================================
-- 2. TABEL: user_tokens (Sesi Token Sesi Login 1 Jam)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS user_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    auth_key VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT fk_user_tokens_user
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON UPDATE CASCADE 
        ON DELETE CASCADE
);

-- ==============================================================================
-- 3. TABEL: master_quests (Katalog Induk Misi Gaya Hidup)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS master_quests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN ('Workout', 'Cardio', 'Appearance', 'Study', 'Mystery')),
    base_exp INT DEFAULT 25 CHECK (base_exp >= 0),
    target_stat VARCHAR(10) NOT NULL CHECK (target_stat IN ('STR', 'AGI', 'INT', 'CHA')),
    min_rank VARCHAR(5) DEFAULT 'F' CHECK (min_rank IN ('F', 'E', 'D', 'C', 'B', 'A', 'S')),
    description TEXT,
    base_gold INT DEFAULT 10 CHECK (base_gold >= 0),
    unit VARCHAR(30) DEFAULT 'Reps', -- 'Reps', 'Km', 'Checklist', 'Menit'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==============================================================================
-- 4. TABEL: daily_user_quests (Alokasi & Progres Quest Harian per Hunter)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS daily_user_quests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    quest_id UUID NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'penalty')),
    target_value INT NOT NULL CHECK (target_value > 0),
    achieved_value INT DEFAULT 0 CHECK (achieved_value >= 0),
    date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT fk_daily_user_quests_user
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON UPDATE CASCADE 
        ON DELETE CASCADE,
    CONSTRAINT fk_daily_user_quests_master
        FOREIGN KEY (quest_id) 
        REFERENCES master_quests(id) 
        ON UPDATE CASCADE 
        ON DELETE CASCADE
);

-- ==============================================================================
-- 5. TABEL: item_shop (Etalase Guild Shop & Koleksi Bergengsi)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS item_shop (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    description TEXT,
    price_gold INT NOT NULL CHECK (price_gold >= 0),
    pride_score INT DEFAULT 0 CHECK (pride_score >= 0),
    category VARCHAR(50) DEFAULT 'Consumable' CHECK (category IN ('Consumable', 'PrideItem', 'Ticket')),
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==============================================================================
-- 6. TABEL: blockchain_inventory_logs (Rantai Blok SHA-256 Pembelian Item)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS blockchain_inventory_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    item_id UUID NOT NULL,
    previous_hash VARCHAR(255) NOT NULL,
    current_hash VARCHAR(255) NOT NULL,
    timestamp VARCHAR(100) NOT NULL,
    status VARCHAR(30) DEFAULT 'verified' CHECK (status IN ('verified', 'pending', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT fk_blockchain_logs_user
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON UPDATE CASCADE 
        ON DELETE CASCADE,
    CONSTRAINT fk_blockchain_logs_item
        FOREIGN KEY (item_id) 
        REFERENCES item_shop(id) 
        ON UPDATE CASCADE 
        ON DELETE CASCADE
);

-- ==============================================================================
-- 7. TABEL: saran_kesan (Evaluasi Akademik Mata Kuliah Pemrograman Mobile)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS saran_kesan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    nama_mahasiswa VARCHAR(150) NOT NULL,
    nim VARCHAR(50) NOT NULL,
    kesan TEXT NOT NULL,
    saran TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT fk_saran_kesan_user
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON UPDATE CASCADE 
        ON DELETE CASCADE
);

-- ==============================================================================
-- PENGATURAN INDEX UNTUK PERFORMA TINGGI
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_daily_quests_lookup ON daily_user_quests(user_id, date, status);
CREATE INDEX IF NOT EXISTS idx_blockchain_logs_user_ts ON blockchain_inventory_logs(user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_item_shop_pride ON item_shop(pride_score DESC);

-- ==============================================================================
-- MATIKAN ROW LEVEL SECURITY (RLS) UNTUK TESTING & DEMO
-- ==============================================================================
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_tokens DISABLE ROW LEVEL SECURITY;
ALTER TABLE master_quests DISABLE ROW LEVEL SECURITY;
ALTER TABLE daily_user_quests DISABLE ROW LEVEL SECURITY;
ALTER TABLE item_shop DISABLE ROW LEVEL SECURITY;
ALTER TABLE blockchain_inventory_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE saran_kesan DISABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- SEED DATA AWAL: master_quests (4 Pilar Solo Leveling)
-- ==============================================================================
INSERT INTO master_quests (id, title, category, base_exp, target_stat, min_rank, description, base_gold, unit)
VALUES
    ('a0000001-0000-0000-0000-000000000001', 'Push-up Physical Protocol', 'Workout', 30, 'STR', 'F', 'Lakukan push-up dengan form sempurna yang divalidasi oleh kamera AI', 20, 'Reps'),
    ('a0000001-0000-0000-0000-000000000002', 'Squat Core Training', 'Workout', 30, 'STR', 'F', 'Latihan otot kaki bawah dan panggul terpantau sensor postur', 20, 'Reps'),
    ('a0000001-0000-0000-0000-000000000003', '3K Dungeon Perimeter Sprint', 'Cardio', 35, 'AGI', 'F', 'Lari 3 kilometer dengan validasi kecepatan anti-kendaraan pedometer', 25, 'Km'),
    ('a0000001-0000-0000-0000-000000000004', 'Daily Grooming & Sunscreen', 'Appearance', 20, 'CHA', 'F', 'Rutinitas perawatan wajah dan tabir surya pelindung radiasi UV', 15, 'Checklist'),
    ('a0000001-0000-0000-0000-000000000005', 'Deep Work & Trivia Mastery', 'Study', 40, 'INT', 'F', 'Fokus belajar 45 menit bebas gangguan diakhiri uji kuis pengetahuan', 30, 'Menit')
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- SEED DATA AWAL: item_shop (Consumables & Pride Items)
-- ==============================================================================
INSERT INTO item_shop (id, name, description, price_gold, pride_score, category, image_url)
VALUES
    ('b0000001-0000-0000-0000-000000000001', 'Lesser HP Potion', 'Memulihkan +20 HP saat terkena penalti sistem', 150, 0, 'Consumable', null),
    ('b0000001-0000-0000-0000-000000000002', 'Full Recovery Elixir', 'Memulihkan HP kembali ke 100 secara instan', 600, 0, 'Consumable', null),
    ('b0000001-0000-0000-0000-000000000003', 'Mystery Dungeon Key', 'Membuka akses ke gerbang Mystery Quest berhadiah langka', 500, 50, 'Ticket', null),
    ('b0000001-0000-0000-0000-000000000004', 'Demon Monarch Dagger', 'Artefak koleksi legendaris penentu posisi peringkat Leaderboard', 2500, 250, 'PrideItem', null),
    ('b0000001-0000-0000-0000-000000000005', 'Shadow Sovereign Cloak', 'Jubah kebanggaan tingkat tinggi beraura gelap penambah Pride Point', 5000, 600, 'PrideItem', null)
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- CONTOH HTTP REST API QUERY FLUTTER (POSTGREST RESOURCE EMBEDDING)
-- ==============================================================================
-- 1. Ambil Daily Quests JOIN Master Quests Hari Ini:
-- GET /rest/v1/daily_user_quests?user_id=eq.{USER_UUID}&date=eq.{TODAY}&select=*,master_quests(*)
--
-- 2. Ambil Transaksi Terakhir Pembelian Item (Previous Hash):
-- GET /rest/v1/blockchain_inventory_logs?user_id=eq.{USER_UUID}&order=timestamp.desc&limit=1
--
-- 3. Catat Blok Pembelian Item Baru:
-- POST /rest/v1/blockchain_inventory_logs
-- Body: {"id": "UUID", "user_id": "UUID", "item_id": "UUID", "previous_hash": "...", "current_hash": "...", "timestamp": "..."}