-- Migration: Create Storage Buckets for Image Uploads
-- Description: Setup storage policies for user image uploads
-- Version: 002

-- Create storage bucket for user images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user-images', 
    'user-images', 
    false, 
    5242880, -- 5MB limit per image
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Create RLS policies for storage
-- Users can upload images to their own folder
CREATE POLICY "Users can upload images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'user-images' AND 
        auth.role() IN ('member', 'nonmember', 'admin') AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Users can view their own images
CREATE POLICY "Users can view own images" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'user-images' AND 
        (storage.foldername(name))[1] = auth.uid()::text OR
        auth.role() = 'admin')
    );

-- Users can update their own images
CREATE POLICY "Users can update own images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'user-images' AND 
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Users can delete their own images
CREATE POLICY "Users can delete own images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'user-images' AND 
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Admins can view all images
CREATE POLICY "Admins can view all images" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'user-images' AND 
        auth.role() = 'admin'
    );
