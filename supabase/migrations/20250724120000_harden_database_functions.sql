/*
# [SECURITY] Harden Database Functions
This migration hardens the security of the database functions by explicitly setting the search_path. This mitigates the "Function Search Path Mutable" warning from Supabase and prevents potential attack vectors where a user could manipulate the function execution path.

## Query Description:
This operation modifies the `can_view_channel` and `handle_new_user` functions to set a fixed `search_path`. This is a non-destructive security enhancement and has no impact on existing data.

## Metadata:
- Schema-Category: ["Safe", "Security"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Modifies function: `public.can_view_channel(uuid)`
- Modifies function: `public.handle_new_user()`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: Admin privileges to alter functions.
- Mitigates: `Function Search Path Mutable` security advisory.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible.
*/

-- Harden the can_view_channel function to prevent search path hijacking
ALTER FUNCTION public.can_view_channel(channel_id_to_check uuid)
SET search_path = '';

-- Harden the handle_new_user trigger function to prevent search path hijacking
ALTER FUNCTION public.handle_new_user()
SET search_path = '';
