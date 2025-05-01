import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Types for our marketplace items
export type MarketplaceItem = {
  id: string;
  created_at: string;
  title: string;
  description: string;
  price_usd: number;
  image_urls: string[];
  seller_address: string;
  status: 'available' | 'sold';
  contact_email?: string;
  contact_phone?: string;
}; 