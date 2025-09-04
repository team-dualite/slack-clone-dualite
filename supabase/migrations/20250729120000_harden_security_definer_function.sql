/*
# [Operation] Harden Security Definer Function
This migration updates the `can_user_access_channel` function to set a fixed `search_path`. This is a security best practice that prevents potential search path hijacking attacks, resolving the "Function Search Path Mutable" warning from the Supabase security advisor.

## Query Description:
- This operation modifies an existing function.
- It is a non-destructive change and has no impact on existing data.
- It improves the security and stability of the Row Level Security policies that depend on this function.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by reverting to the previous function definition)

## Structure Details:
- Modifies function: `public.can_user_access_channel(bigint)`

## Security Implications:
- RLS Status: Enabled
- Policy Changes: No
- Auth Requirements: This function is used by RLS policies.
- Mitigates: Search path hijacking vulnerability.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. May slightly improve performance by providing a fixed path for the query planner.
*/

ALTER FUNCTION public.can_user_access_channel(channel_id_to_check bigint)
SET search_path = public;
