-- Create user profiles table with role selection
create table public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  phone text,
  avatar_url text,
  role text check (role in ('customer', 'farmer', 'rider')),
  onboarding_completed boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Enable RLS
alter table public.user_profiles enable row level policy;

-- Create policy: Users can view their own profile
create policy "Users can view own profile"
  on public.user_profiles for select
  using (auth.uid() = id);

-- Create policy: Users can insert their own profile
create policy "Users can insert own profile"
  on public.user_profiles for insert
  with check (auth.uid() = id);

-- Create policy: Users can update their own profile
create policy "Users can update own profile"
  on public.user_profiles for update
  using (auth.uid() = id);

-- Create trigger to automatically create profile on user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.user_profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$ language plpgsql security definer;

-- Drop trigger if exists
drop trigger if exists on_auth_user_created on auth.users;

-- Create trigger
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Create index for faster lookups
create index idx_user_profiles_role on public.user_profiles(role);
create index idx_user_profiles_onboarding on public.user_profiles(onboarding_completed) where onboarding_completed = false;
