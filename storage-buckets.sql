-- Koperasi Finance Storage Buckets Configuration
-- For handling user uploaded images (receipts, payment proofs, contribution proofs)

-- ================================================
-- STORAGE BUCKETS
-- ================================================

-- Main bucket for all user uploaded images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user-images', 
    'user-images', 
    false, 
    5242880, -- 5MB limit per image
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- ================================================
-- STORAGE POLICIES
-- ================================================

-- Users can upload images to their own folder structure
CREATE POLICY "Users can upload images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'user-images' AND 
        auth.role() IN ('member', 'nonmember', 'admin') AND
        (storage.foldername(name)[1] = auth.uid()::text)
    );

-- Users can view their own images
CREATE POLICY "Users can view own images" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'user-images' AND 
        (storage.foldername(name)[1] = auth.uid()::text OR
        auth.role() = 'admin')
    );

-- Users can update their own images
CREATE POLICY "Users can update own images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'user-images' AND 
        storage.foldername(name)[1] = auth.uid()::text
    );

-- Users can delete their own images
CREATE POLICY "Users can delete own images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'user-images' AND 
        storage.foldername(name)[1] = auth.uid()::text
    );

-- Admins can view all images
CREATE POLICY "Admins can view all images" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'user-images' AND 
        auth.role() = 'admin'
    );

-- ================================================
-- FOLDER STRUCTURE FOR STORAGE
-- ================================================
-- Images will be stored in folder structure:
-- user-images/{user_id}/{image_type}/{image_id}
-- Examples:
-- user-images/550e8400-e29b-41d4-a716-446655440001/receipt/abc123.jpg
-- user-images/550e8400-e29b-41d4-a716-446655440001/payment_proof/def456.png
-- user-images/550e8400-e29b-41d4-a716-446655440001/contribution_proof/ghi789.jpg
