-- Migration: Create User Tables and Photo Upload System
-- Description: Initial database setup for Koperasi Finance
-- Version: 001

-- Create users table with role-based access
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

-- Create loans table
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

-- Create payments table with image support
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    payment_type VARCHAR(20) NOT NULL CHECK (payment_type IN ('principal', 'interest', 'penalty')),
    receipt_image_url TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create contributions table with image support
CREATE TABLE IF NOT EXISTS contributions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    contribution_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    receipt_image_url TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create money transfers table with image support
CREATE TABLE IF NOT EXISTS money_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    to_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    transfer_type VARCHAR(20) NOT NULL CHECK (transfer_type IN ('loan_disbursement', 'payment', 'refund', 'contribution')),
    transfer_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    proof_image_url TEXT,
    notes TEXT,
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'completed', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user_images table for tracking all uploaded images
CREATE TABLE IF NOT EXISTS user_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    image_type VARCHAR(20) NOT NULL CHECK (image_type IN ('receipt', 'payment_proof', 'contribution_proof', 'profile_picture')),
    related_entity_type VARCHAR(20),
    related_entity_id UUID,
    uploaded_by UUID REFERENCES users(id) ON DELETE CASCADE,
    upload_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT false
);

-- Create performance indexes
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

-- Insert sample admin user for testing
INSERT INTO users (id, username, email, password_hash, full_name, phone, role) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'admin', 'admin_hash', 'System Administrator', '+254743409438', 'admin')
ON CONFLICT (email) DO NOTHING;
