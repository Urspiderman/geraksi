-- GERAKSI: jalankan sekali di Supabase SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text not null default '',role text not null default 'student' check(role in ('student','admin')),points integer not null default 0 check(points>=0),created_at timestamptz not null default now());
create table if not exists public.trips(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,origin text not null,destination text not null,mode text not null check(mode in ('bus','walk','bike','motorcycle')),distance_km numeric(8,2) not null check(distance_km>0 and distance_km<=100),cost_idr integer not null default 0 check(cost_idr>=0),baseline_kg numeric(10,3) not null default 0,actual_kg numeric(10,3) not null default 0,status text not null default 'planned' check(status in ('planned','pending','approved','rejected')),proof_path text,points_awarded integer not null default 0,created_at timestamptz not null default now());
create table if not exists public.rewards(id uuid primary key default gen_random_uuid(),name text not null unique,description text not null default '',points_cost integer not null check(points_cost>0),stock integer not null default 0 check(stock>=0),active boolean not null default true);
create table if not exists public.redemptions(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,reward_id uuid not null references public.rewards(id),points_spent integer not null,status text not null default 'pending' check(status in ('pending','fulfilled','cancelled')),created_at timestamptz not null default now());
create or replace function public.on_new_user() returns trigger language plpgsql security definer set search_path=public as $$begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','Mahasiswa')) on conflict(id) do nothing;return new;end$$;
drop trigger if exists auth_user_created_geraksi on auth.users;
create trigger auth_user_created_geraksi after insert on auth.users for each row execute function public.on_new_user();
insert into public.profiles(id,full_name) select id,coalesce(raw_user_meta_data->>'full_name','Mahasiswa') from auth.users on conflict(id) do nothing;
alter table public.profiles enable row level security;
alter table public.trips enable row level security;
alter table public.rewards enable row level security;
alter table public.redemptions enable row level security;
drop policy if exists profile_own_read on public.profiles;
create policy profile_own_read on public.profiles for select to authenticated using(id=auth.uid());
drop policy if exists trips_own_read on public.trips;
create policy trips_own_read on public.trips for select to authenticated using(user_id=auth.uid() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));
drop policy if exists trips_own_insert on public.trips;
create policy trips_own_insert on public.trips for insert to authenticated with check(user_id=auth.uid() and status='planned' and proof_path is null and points_awarded=0 and baseline_kg=round(distance_km*0.1,3) and actual_kg=round(distance_km*(case mode when 'bus' then 0.05 when 'motorcycle' then 0.1 else 0 end),3));
-- Client may submit proof only for own planned trip. Awarding points is exclusively RPC.
drop policy if exists trips_own_proof on public.trips;
create policy trips_own_proof on public.trips for update to authenticated using(user_id=auth.uid() and status='planned') with check(user_id=auth.uid() and status='pending' and proof_path is not null and points_awarded=0);
drop policy if exists rewards_read on public.rewards;
create policy rewards_read on public.rewards for select to authenticated using(active=true);
drop policy if exists redemptions_read on public.redemptions;
create policy redemptions_read on public.redemptions for select to authenticated using(user_id=auth.uid());
-- Protect trip immutable fields against edits via RLS-permitted proof update.
create or replace function public.protect_trip_update() returns trigger language plpgsql as $$begin
if current_setting('app.trusted_review',true) is distinct from 'yes' then
 if new.user_id is distinct from old.user_id or new.origin is distinct from old.origin or new.destination is distinct from old.destination or new.mode is distinct from old.mode or new.distance_km is distinct from old.distance_km or new.cost_idr is distinct from old.cost_idr or new.baseline_kg is distinct from old.baseline_kg or new.actual_kg is distinct from old.actual_kg or new.points_awarded is distinct from old.points_awarded or old.status<>'planned' or new.status<>'pending' or new.proof_path not like old.user_id::text||'/'||old.id::text||'/%' then raise exception 'Invalid trip update';end if;
end if;return new;end$$;
drop trigger if exists guard_trip_update on public.trips;
create trigger guard_trip_update before update on public.trips for each row execute function public.protect_trip_update();
create or replace function public.review_trip(p_trip_id uuid,p_approve boolean) returns void language plpgsql security definer set search_path=public as $$declare t public.trips%rowtype;begin
if not exists(select 1 from public.profiles where id=auth.uid() and role='admin') then raise exception 'Admin only';end if;
select * into t from public.trips where id=p_trip_id and status='pending' for update;if not found then raise exception 'Trip not pending';end if;
perform set_config('app.trusted_review','yes',true);
update public.trips set status=case when p_approve then 'approved' else 'rejected' end,points_awarded=case when p_approve and t.baseline_kg>t.actual_kg then 10 else 0 end where id=t.id;
if p_approve and t.baseline_kg>t.actual_kg then update public.profiles set points=points+10 where id=t.user_id;end if;
end$$;
create or replace function public.redeem_reward(p_reward_id uuid) returns void language plpgsql security definer set search_path=public as $$declare r public.rewards%rowtype;balance integer;begin
if auth.uid() is null then raise exception 'Login required';end if;
select * into r from public.rewards where id=p_reward_id and active=true for update;if not found or r.stock<1 then raise exception 'Reward tidak tersedia';end if;
select points into balance from public.profiles where id=auth.uid() for update;if balance<r.points_cost then raise exception 'Poin tidak cukup';end if;
update public.profiles set points=points-r.points_cost where id=auth.uid();update public.rewards set stock=stock-1 where id=r.id;
insert into public.redemptions(user_id,reward_id,points_spent) values(auth.uid(),r.id,r.points_cost);
end$$;
revoke all on function public.review_trip(uuid,boolean) from public;grant execute on function public.review_trip(uuid,boolean) to authenticated;
revoke all on function public.redeem_reward(uuid) from public;grant execute on function public.redeem_reward(uuid) to authenticated;
insert into public.rewards(name,description,points_cost,stock) values('Voucher Transportasi','Voucher perjalanan dari mitra (simulasi)',100,50),('Voucher Makan & Minum','Voucher mitra usaha (simulasi)',150,30),('Paket Data','Reward mitra (simulasi)',200,20) on conflict(name) do nothing;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('trip-proofs','trip-proofs',false,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
drop policy if exists trip_proof_upload on storage.objects;
create policy trip_proof_upload on storage.objects for insert to authenticated with check(bucket_id='trip-proofs' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists trip_proof_read on storage.objects;
create policy trip_proof_read on storage.objects for select to authenticated using(bucket_id='trip-proofs' and ((storage.foldername(name))[1]=auth.uid()::text or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin')));
-- PROMOSI ADMIN: setelah daftar akun, jalankan manual dengan email yang benar:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='admin@kampus.ac.id');
