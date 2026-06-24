# Row-Level Security

The initial migration enables RLS on every public user-owned table. Policies follow the same principle:

- Authenticated users can only select, insert, update, and delete rows where `auth.uid() = user_id`.
- `profiles` uses `id` as the user reference because it mirrors `auth.users(id)`.
- A `handle_new_user` trigger creates a profile and settings row when Supabase Auth creates a new user.

Use service-role credentials only in trusted backend environments. The frontend must use only `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
