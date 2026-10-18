-- ============================================================
-- 1. TABEL USERS (Pengembangan dari tabel member + Statistik RPG)
-- Menyimpan akun, password SHA-256, data fisik BMI, & Status Window
-- ============================================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL, -- Enkripsi SHA-256 (Tanpa Firebase)
    biometric_enabled BOOLEAN DEFAULT FALSE,
    is_onboarded BOOLEAN DEFAULT FALSE,
    
    -- Statistik Fisik Awal (Onboarding)
    tb_cm DOUBLE PRECISION DEFAULT 0,
    bb_kg DOUBLE PRECISION DEFAULT 0,
    bmi DOUBLE PRECISION DEFAULT 0,
    max_pushup INT DEFAULT 10,
    max_situp INT DEFAULT 10,
    max_squat INT DEFAULT 10,
    max_pullup INT DEFAULT 5,
    max_run_km DOUBLE PRECISION DEFAULT 2.0,
    pace_2km_menit DOUBLE PRECISION DEFAULT 15.0,
    
    -- Atribut Gamifikasi Solo Leveling (Status Window)
    level INT DEFAULT 1,
    rank VARCHAR(5) DEFAULT 'F', -- F, E, D, C, B, A, S
    hp INT DEFAULT 100,          -- Maks 100, jika 0 = Anda Tidak Layak
    exp INT DEFAULT 0,           -- 100 EXP = Naik 1 Level
    gold INT DEFAULT 0,          -- Diuangkan di Guild Exchange (IDR, USD, EUR)
    is_penalty_active BOOLEAN DEFAULT FALSE,
    last_active_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- 2. TABEL USER_TOKENS (Sesuai tabel member_token di Modul)
-- Mencatat token sesi login & waktu kedaluwarsa sesi 1 jam
-- ============================================================
CREATE TABLE user_tokens (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    auth_key VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT fk_user_token
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON UPDATE CASCADE 
        ON DELETE CASCADE
);

-- ============================================================
-- 3. TABEL QUEST_HISTORY (Sinkronisasi Online Quest & Kalori)
-- Menyimpan backup quest harian yang disinkronkan dari Hive
-- ============================================================
CREATE TABLE quest_history (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    local_quest_id VARCHAR(100),
    title VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL, -- Workout, Cardio, Skincare, Study, Work, Kalori
    target_value INT NOT NULL,
    current_value INT DEFAULT 0,
    unit VARCHAR(30) NOT NULL,     -- Reps, Km, Jam, Checklist, Kkal
    exp_reward INT DEFAULT 20,
    gold_reward INT DEFAULT 10,
    is_completed BOOLEAN DEFAULT FALSE,
    is_penalty_quest BOOLEAN DEFAULT FALSE,
    quest_date DATE DEFAULT CURRENT_DATE,
    CONSTRAINT fk_user_quest
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON UPDATE CASCADE 
        ON DELETE CASCADE
);

-- ============================================================
-- 4. TABEL BLOCKCHAIN_LEDGER (Backup Cloud Rantai Blok Anti-Cheat)
-- Menyimpan riwayat hash SHA-256 saat naik Level/Rank atau Reset
-- ============================================================
CREATE TABLE blockchain_ledger (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    block_index INT NOT NULL,
    timestamp VARCHAR(100) NOT NULL,
    action_data TEXT NOT NULL,     -- Contoh: "LEVEL UP: Level 2 (Rank F)"
    prev_hash VARCHAR(255) NOT NULL,
    current_hash VARCHAR(255) NOT NULL,
    CONSTRAINT fk_user_blockchain
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON UPDATE CASCADE 
        ON DELETE CASCADE
);

-- ============================================================
-- 5. TABEL SARAN_KESAN (Menu Wajib Bottom Navigation Bar)
-- Menyimpan saran & kesan mata kuliah Pemrograman Aplikasi Mobile
-- ============================================================
CREATE TABLE saran_kesan (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    nama_mahasiswa VARCHAR(150) NOT NULL,
    nim VARCHAR(50) NOT NULL,
    kesan TEXT NOT NULL,
    saran TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT fk_user_feedback
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON UPDATE CASCADE 
        ON DELETE CASCADE
);

-- ============================================================
-- PENTING UNTUK DEMO TUGAS AKHIR:
-- Matikan Row Level Security (RLS) agar REST API Flutter bisa 
-- langsung melakukan CRUD menggunakan anon key tanpa error 401/403
-- ============================================================
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_tokens DISABLE ROW LEVEL SECURITY;
ALTER TABLE quest_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE blockchain_ledger DISABLE ROW LEVEL SECURITY;
ALTER TABLE saran_kesan DISABLE ROW LEVEL SECURITY;