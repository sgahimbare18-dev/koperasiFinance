-- Koperasi Finance Database Schema
-- Photo Upload System for Money Transfers, Payments, and Contributions

-- ================================================
-- USERS TABLE
-- ================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    role VARCHAR(20) NOT NULL CHECK (role IN ('member', 'nonmember', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- ================================================
-- LOANS TABLE
-- ================================================
CREATE TABLE IF NOT EXISTS loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    interest_rate DECIMAL(5,4) NOT NULL,
    duration_months INTEGER NOT NULL,
    monthly_payment DECIMAL(10,2),
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'approved', 'active', 'completed', 'defaulted')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    remaining_balance DECIMAL(10,2) NOT NULL
);

-- ================================================
-- PAYMENTS TABLE
-- ================================================
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    payment_type VARCHAR(20) NOT NULL CHECK (payment_type IN ('principal', 'interest', 'penalty')),
    receipt_image_url TEXT, -- URL to uploaded receipt image
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ================================================
-- CONTRIBUTIONS TABLE
-- ================================================
CREATE TABLE IF NOT EXISTS contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    contribution_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    receipt_image_url TEXT, -- URL to uploaded contribution receipt image
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ================================================
-- MONEY TRANSFERS TABLE
-- ================================================
CREATE TABLE IF NOT EXISTS money_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    to_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    transfer_type VARCHAR(20) NOT NULL CHECK (transfer_type IN ('loan_disbursement', 'payment', 'refund', 'contribution')),
    transfer_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    proof_image_url TEXT, -- URL to uploaded proof of transfer image
    notes TEXT,
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'completed', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ================================================
-- USER_IMAGES TABLE
-- ================================================
CREATE TABLE IF NOT EXISTS user_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    image_type VARCHAR(20) NOT NULL CHECK (image_type IN ('receipt', 'payment_proof', 'contribution_proof', 'profile_picture')),
    related_entity_type VARCHAR(20), -- 'payment', 'contribution', 'loan', 'transfer'
    related_entity_id UUID, -- References payment_id, contribution_id, loan_id, or money_transfer_id
    uploaded_by UUID REFERENCES users(id) ON DELETE CASCADE, -- Who uploaded the image
    upload_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT false
);

-- ================================================
-- ADMIN_IMAGE_VIEWS (For Admin to View User Images)
-- ================================================
CREATE OR REPLACE VIEW admin_user_images AS
SELECT 
    ui.id,
    ui.user_id,
    ui.image_url,
    ui.image_type,
    ui.related_entity_type,
    ui.related_entity_id,
    ui.upload_date,
    ui.is_verified,
    u.username as uploader_name,
    u.full_name as uploader_full_name,
    target_u.username as target_user_name,
    target_u.full_name as target_user_full_name
FROM user_images ui
LEFT JOIN users u ON ui.uploaded_by = u.id
LEFT JOIN users target_u ON ui.user_id = target_u.id
ORDER BY ui.upload_date DESC;

-- ================================================
-- INDEXES FOR PERFORMANCE
-- ================================================
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_loans_user_id ON loans(user_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON loans(status);
CREATE INDEX IF NOT EXISTS idx_payments_loan_id ON payments(loan_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_contributions_user_id ON contributions(user_id);
CREATE INDEX IF NOT EXISTS idx_money_transfers_from_user ON money_transfers(from_user_id);
CREATE INDEX IF NOT EXISTS idx_money_transfers_to_user ON money_transfers(to_user_id);
CREATE INDEX IF NOT EXISTS idx_user_images_user_id ON user_images(user_id);
CREATE INDEX IF NOT EXISTS idx_user_images_upload_date ON user_images(upload_date);

-- ================================================
-- RLS (ROW LEVEL SECURITY) POLICIES
-- ================================================

-- Users can only see their own data
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

-- Users can only see their own loans
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own loans" ON loans
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own loans" ON loans
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can only see their own payments
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own payments" ON payments
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own payments" ON payments
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can only see their own contributions
ALTER TABLE contributions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own contributions" ON contributions
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own contributions" ON contributions
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can see transfers they're involved in
ALTER TABLE money_transfers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own transfers" ON money_transfers
    FOR SELECT USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);
CREATE POLICY "Users can create transfers" ON money_transfers
    FOR INSERT WITH CHECK (auth.uid() = from_user_id);

-- Users can only see their own images
ALTER TABLE user_images ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own images" ON user_images
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can upload images" ON user_images
    FOR INSERT WITH CHECK (auth.uid() = uploaded_by);

-- Admins can see all images through the view
CREATE POLICY "Admins can view all images" ON user_images
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ================================================
-- INSERT SAMPLE DATA (for testing)
-- ================================================
INSERT INTO users (id, username, email, password_hash, full_name, phone, role) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'admin', 'admin_hash', 'System Administrator', '+254743409438', 'admin'),
('550e8400-e29b-41d4-a716-446655440001', 'member1', 'member_hash', 'John Member', '+25471234567', 'member'),
('550e8400-e29b-41d4-a716-446655440002', 'nonmember1', 'nonmember_hash', 'Jane NonMember', '+25479876543', 'nonmember')
ON CONFLICT (email) DO NOTHING;
