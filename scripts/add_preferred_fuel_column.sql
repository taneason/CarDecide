ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS preferred_fuel text DEFAULT 'RON95 (Floating)';
