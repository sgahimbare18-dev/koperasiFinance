// Supabase Client Configuration
// For browser compatibility, we'll use CDN instead of ES6 modules
const { createClient } = window.supabase;

// Initialize Supabase client
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://vkcjwovhnmluzqkgqrbk.supabase.co';
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || 'your-publishable-key';

export const supabase = createClient(supabaseUrl, supabaseKey);

// Storage configuration for user uploaded images
export const STORAGE_BUCKETS = {
  USER_IMAGES: 'user-images'
};

export const IMAGE_TYPES = {
  RECEIPT: 'receipt',
  PAYMENT_PROOF: 'payment_proof', 
  CONTRIBUTION_PROOF: 'contribution_proof',
  PROFILE_PICTURE: 'profile_picture'
};

export const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB

// Database table names
export const TABLES = {
  USERS: 'users',
  LOANS: 'loans',
  PAYMENTS: 'payments',
  CONTRIBUTIONS: 'contributions',
  MONEY_TRANSFERS: 'money_transfers',
  USER_IMAGES: 'user_images'
};

// Helper functions for image uploads
export async function uploadImage(file, userId, imageType, relatedEntityId = null) {
  if (!file) {
    throw new Error('No file provided');
  }

  // Validate file
  if (!file.type.startsWith('image/')) {
    throw new Error('Only image files are allowed');
  }

  if (file.size > MAX_FILE_SIZE) {
    throw new Error('File size must be less than 5MB');
  }

  try {
    // Generate unique file path
    const fileExt = file.name.split('.').pop();
    const fileName = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}.${fileExt}`;
    const filePath = `${userId}/${imageType}/${fileName}`;

    // Upload file to Supabase Storage
    const { data, error } = await supabase.storage
      .from(STORAGE_BUCKETS.USER_IMAGES)
      .upload(filePath, file, {
        cacheControl: '3600',
        upsert: true
      });

    if (error) {
      throw new Error(`Upload failed: ${error.message}`);
    }

    // Get public URL
    const { data: { publicUrl } } = supabase.storage
      .from(STORAGE_BUCKETS.USER_IMAGES)
      .getPublicUrl(filePath);

    if (error) {
      throw new Error(`Failed to get public URL: ${error.message}`);
    }

    // Store image metadata in database
    const { error: dbError } = await supabase
      .from(TABLES.USER_IMAGES)
      .insert({
        user_id: userId,
        image_url: publicUrl,
        image_type: imageType,
        related_entity_type: relatedEntityId,
        uploaded_by: userId,
        upload_date: new Date().toISOString()
      });

    if (dbError) {
      throw new Error(`Failed to save image metadata: ${dbError.message}`);
    }

    return {
      success: true,
      imageUrl: publicUrl,
      metadata: {
        fileName,
        filePath,
        size: file.size,
        type: file.type
      }
    };
  } catch (error) {
    throw new Error(`Image upload failed: ${error.message}`);
  }
}

// Authentication helpers
export async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
    options: {
      redirectTo: window.location.origin // Redirect back to your app after login
    }
  });

  if (error) {
    throw new Error(`Login failed: ${error.message}`);
  }

  return data.user;
}


export async function signInWithGoogle() {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${window.location.origin}/portal.html`,
      queryParams: {
        access_type: 'offline',
        prompt: 'consent',
      }
    }
  });

  if (error) {
    throw new Error(`Google sign-in failed: ${error.message}`);
  }

  return data.user;
}




// Real-time subscriptions
export function subscribeToTable(tableName, callback) {
  return supabase
    .channel(`public:${tableName}`)
    .on('postgres_changes', (payload) => {
      if (payload.eventType === 'INSERT' || payload.eventType === 'UPDATE') {
        callback(payload);
      }
    })
    .subscribe();
}

// Database operations
export const db = {
  // Users
  async getUser(userId) {
    const { data, error } = await supabase
      .from(TABLES.USERS)
      .select('*')
      .eq('id', userId)
      .single();

    if (error) {
      throw new Error(`Failed to get user: ${error.message}`);
    }

    return data;
  },

  async createUser(userData) {
    const { data, error } = await supabase
      .from(TABLES.USERS)
      .insert(userData);

    if (error) {
      throw new Error(`Failed to create user: ${error.message}`);
    }

    return data;
  },

  // Loans
  async getLoans(userId = null) {
    let query = supabase.from(TABLES.LOANS).select('*');

    if (userId) {
      query = query.eq('user_id', userId);
    }

    const { data, error } = await query;

    if (error) {
      throw new Error(`Failed to get loans: ${error.message}`);
    }

    return data || [];
  },

  async createLoan(loanData) {
    const { data, error } = await supabase
      .from(TABLES.LOANS)
      .insert(loanData);

    if (error) {
      throw new Error(`Failed to create loan: ${error.message}`);
    }

    return data;
  },

  async updateLoan(loanId, updates) {
    const { data, error } = await supabase
      .from(TABLES.LOANS)
      .update(updates)
      .eq('id', loanId);

    if (error) {
      throw new Error(`Failed to update loan: ${error.message}`);
    }

    return data;
  },

  // Payments
  async createPayment(paymentData) {
    const { data, error } = await supabase
      .from(TABLES.PAYMENTS)
      .insert(paymentData);

    if (error) {
      throw new Error(`Failed to create payment: ${error.message}`);
    }

    return data;
  },

  // Contributions
  async createContribution(contributionData) {
    const { data, error } = await supabase
      .from(TABLES.CONTRIBUTIONS)
      .insert(contributionData);

    if (error) {
      throw new Error(`Failed to create contribution: ${error.message}`);
    }

    return data;
  },

  // User Images
  async getUserImages(userId = null) {
    let query = supabase
      .from(TABLES.USER_IMAGES)
      .select(`
        *,
        users!inner (
          username,
          full_name
        )
      `);

    // If userId is null, get all images (admin access)
    if (!userId) {
      const { data: adminData } = await supabase
        .from('admin_user_images')
        .select('*');

      if (!adminData.error) {
        return adminData || [];
      }
    } else {
      query = query.eq('user_id', userId);
    }

    const { data, error } = await query;

    if (error) {
      throw new Error(`Failed to get user images: ${error.message}`);
    }

    return data || [];
  },

  async verifyImage(imageId, isVerified) {
    const { data, error } = await supabase
      .from(TABLES.USER_IMAGES)
      .update({ is_verified: isVerified })
      .eq('id', imageId);

    if (error) {
      throw new Error(`Failed to verify image: ${error.message}`);
    }

    return data;
  }
};
