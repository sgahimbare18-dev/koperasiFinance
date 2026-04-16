# Supabase Database Schema for Koperasi Finance

## Required Tables

### 1. Users Table
```sql
CREATE TABLE users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  full_name VARCHAR(255),
  phone VARCHAR(50),
  member_id VARCHAR(50) UNIQUE,
  is_member BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 2. Contributions Table
```sql
CREATE TABLE contributions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  month DATE NOT NULL,
  proof_url TEXT,
  notes TEXT,
  status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
  approved_at TIMESTAMP WITH TIME ZONE,
  approved_by UUID REFERENCES users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 3. Loans Table
```sql
CREATE TABLE loans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  purpose VARCHAR(100) NOT NULL,
  description TEXT,
  term_months INTEGER NOT NULL,
  interest_rate DECIMAL(3,2) NOT NULL, -- 0.08 for members, 0.12 for non-members
  collateral_type VARCHAR(50),
  collateral_details TEXT,
  status VARCHAR(20) DEFAULT 'pending', -- pending, approved, disbursed, rejected, completed
  applied_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  approved_date TIMESTAMP WITH TIME ZONE,
  disbursed_date TIMESTAMP WITH TIME ZONE,
  approved_by UUID REFERENCES users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 4. Loan Disbursements Table
```sql
CREATE TABLE loan_disbursements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  loan_id UUID REFERENCES loans(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount_received DECIMAL(10,2) NOT NULL,
  proof_url TEXT,
  notes TEXT,
  confirmed_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 5. Loan Payments Table
```sql
CREATE TABLE loan_payments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  loan_id UUID REFERENCES loans(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  payment_method VARCHAR(50) NOT NULL, -- mpesa, bank, cash
  transaction_reference VARCHAR(100),
  proof_url TEXT,
  notes TEXT,
  payment_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status VARCHAR(20) DEFAULT 'pending', -- pending, confirmed, rejected
  confirmed_at TIMESTAMP WITH TIME ZONE,
  confirmed_by UUID REFERENCES users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 6. Transaction History Table (for dashboard views)
```sql
CREATE TABLE transaction_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL, -- contribution, loan_application, loan_disbursement, payment
  description TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(20) NOT NULL,
  reference_id UUID, -- References the main table ID
  proof_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 7. Profit Sharing Table
```sql
CREATE TABLE profit_sharing (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_contributions DECIMAL(10,2) NOT NULL,
  profit_share_amount DECIMAL(10,2) NOT NULL,
  calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  distributed_at TIMESTAMP WITH TIME ZONE,
  status VARCHAR(20) DEFAULT 'calculated', -- calculated, distributed
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## Storage Buckets

### 1. payment-proofs Bucket
- Store contribution receipts, loan disbursement proofs, payment receipts
- Structure: `contributions/{user_id}/{timestamp}_{filename}`
- Structure: `disbursements/{user_id}/{timestamp}_{filename}`
- Structure: `payments/{user_id}/{timestamp}_{filename}`

## Row Level Security (RLS) Policies

### Users Table
```sql
-- Users can view their own data
CREATE POLICY "Users can view own data" ON users
  FOR SELECT USING (auth.uid() = id);

-- Users can update their own data
CREATE POLICY "Users can update own data" ON users
  FOR UPDATE USING (auth.uid() = id);
```

### Contributions Table
```sql
-- Users can view their own contributions
CREATE POLICY "Users can view own contributions" ON contributions
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own contributions
CREATE POLICY "Users can insert own contributions" ON contributions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admins can view all contributions
CREATE POLICY "Admins can view all contributions" ON contributions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.is_admin = true
    )
  );
```

### Similar RLS policies needed for:
- loans
- loan_disbursements
- loan_payments
- transaction_history
- profit_sharing

## Database Functions

### Calculate Profit Sharing (11-month cycle)
```sql
CREATE OR REPLACE FUNCTION calculate_profit_sharing(user_uuid UUID)
RETURNS DECIMAL(10,2) AS $$
DECLARE
  total_contributions DECIMAL(10,2);
  profit_rate DECIMAL(3,2) := 0.05; -- 5% profit sharing
BEGIN
  SELECT COALESCE(SUM(amount), 0) INTO total_contributions
  FROM contributions
  WHERE user_id = user_uuid
    AND status = 'approved'
    AND created_at >= NOW() - INTERVAL '11 months';
  
  RETURN total_contributions * profit_rate;
END;
$$ LANGUAGE plpgsql;
```

## Setup Instructions

### 1. Create Supabase Project
1. Go to https://supabase.com
2. Create new project
3. Note the project URL and anon key

### 2. Run SQL Commands
1. Go to SQL Editor in Supabase Dashboard
2. Execute each CREATE TABLE statement
3. Create RLS policies
4. Create functions

### 3. Create Storage Buckets
1. Go to Storage section
2. Create `payment-proofs` bucket
3. Set up access policies

### 4. Update Configuration
In `member-dashboard.html`, update:
```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

### 5. Enable Authentication
1. Go to Authentication > Settings
2. Enable email/password authentication
3. Configure email templates
4. Set up redirect URLs

## Features Implemented

### Member Dashboard
- ✅ Overview with statistics
- ✅ Monthly contribution form with image upload
- ✅ Loan application form
- ✅ Loan disbursement confirmation with image upload
- ✅ Payment form with image upload
- ✅ Transaction history with filtering
- ✅ 11-month profit sharing calculation

### Key Features
- 📊 Real-time statistics
- 💰 Contribution tracking
- 📋 Loan management
- 💳 Payment processing
- 📜 Complete transaction history
- 📸 Image proof uploads
- 🔐 Row-level security
- 📱 Responsive design

## Next Steps
1. Set up actual Supabase project
2. Replace placeholder credentials
3. Test all forms with real data
4. Implement authentication
5. Add admin dashboard for approvals
6. Set up automated profit sharing calculations
