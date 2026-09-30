-- Pavera: apply once to a new Supabase project. Demo data never enters this database.
create extension if not exists pgcrypto;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null check(char_length(name) between 2 and 100),
 role text not null default 'Buyer' check(role in ('Buyer','Seller','Agent','Admin')),
 bio text not null default '' check(char_length(bio)<=500),
 city text not null default '', email text not null default '', phone text not null default '',
 photo text, cover text, verified boolean not null default false, created_at timestamptz not null default now()
);
create table public.admins (user_id uuid primary key references public.profiles(id) on delete cascade);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.admins where user_id=auth.uid()) $$;
create table public.categories (name text primary key check(char_length(name) between 2 and 60),enabled boolean not null default true);
insert into public.categories(name) values('Apartment'),('Villa'),('House'),('Plot / Land'),('Office'),('Shop'),('Commercial');
create table public.properties (
 id text primary key default gen_random_uuid()::text,
 owner_id uuid not null references public.profiles(id) on delete cascade,
 title text not null check(char_length(title) between 1 and 160),
 purpose text not null check(purpose in ('Sale','Rent')),
 status text not null default 'Under Review' check(status in ('For Sale','For Rent','Sold','Rented','Under Review','Draft','Paused','Rejected')),
 verified boolean not null default false, featured boolean not null default false,
 details jsonb not null default '{}', created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(jsonb_typeof(details)='object')
);
create index properties_owner on public.properties(owner_id);
create index properties_status on public.properties(status,created_at desc);
create index property_search on public.properties using gin(to_tsvector('simple',title || ' ' || coalesce(details->>'city','') || ' ' || coalesce(details->>'locality','') || ' ' || coalesce(details->>'type','')));
create table public.property_images (id uuid primary key default gen_random_uuid(),property_id text not null references public.properties(id) on delete cascade,url text not null check(url ~ '^https://'),position integer not null default 0,is_primary boolean not null default false,unique(property_id,position));
create table public.amenities (name text primary key);
insert into public.amenities values ('Security'),('Lift'),('Power backup'),('Gym'),('Swimming pool'),('Garden'),('Clubhouse'),('Visitor parking'),('Children’s play area'),('Wi-Fi');
create table public.property_amenities (property_id text references public.properties(id) on delete cascade,amenity_name text references public.amenities(name),primary key(property_id,amenity_name));
create table public.saved_properties(user_id uuid references public.profiles(id) on delete cascade,property_id text references public.properties(id) on delete cascade,created_at timestamptz default now(),primary key(user_id,property_id));
create table public.likes(user_id uuid references public.profiles(id) on delete cascade,property_id text references public.properties(id) on delete cascade,created_at timestamptz default now(),primary key(user_id,property_id));
create table public.comments(id uuid primary key default gen_random_uuid(),property_id text not null references public.properties(id) on delete cascade,user_id uuid not null references public.profiles(id) on delete cascade,name text not null,text text not null check(char_length(trim(text)) between 1 and 2000),created_at timestamptz not null default now());
create table public.conversations(id uuid primary key default gen_random_uuid(),property_id text not null references public.properties(id) on delete cascade,buyer_id uuid not null references public.profiles(id),seller_id uuid not null references public.profiles(id),seller text not null,photo text,archived boolean not null default false,created_at timestamptz not null default now(),unique(property_id,buyer_id,seller_id),check(buyer_id<>seller_id));
create table public.messages(id uuid primary key default gen_random_uuid(),conversation_id uuid not null references public.conversations(id) on delete cascade,sender_id uuid not null references public.profiles(id),text text not null default '' check(char_length(text)<=4000),attachment text,read boolean not null default false,created_at timestamptz not null default now(),check(char_length(trim(text))>0 or attachment is not null),check(attachment is null or attachment ~ '^https://'));
create index message_history on public.messages(conversation_id,created_at);
create table public.notifications(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,title text not null,body text not null,type text not null check(type in ('message','listing','activity','payment','system')),read boolean not null default false,property_id text references public.properties(id) on delete set null,created_at timestamptz not null default now());
create index notification_inbox on public.notifications(user_id,created_at desc);
create table public.payments(id uuid primary key default gen_random_uuid(),property_id text references public.properties(id) on delete set null,buyer_id uuid not null references public.profiles(id),seller_id uuid not null references public.profiles(id),property_title text not null,buyer_name text not null,seller_name text not null,amount bigint not null check(amount>0),currency text not null default 'INR' check(currency='INR'),method text not null default 'Gateway checkout',status text not null default 'Pending' check(status in ('Successful','Pending','Failed','Refunded')),gateway_order_id text unique,gateway_payment_id text unique,checkout_url text,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create unique index one_pending_booking on public.payments(buyer_id,property_id) where status='Pending';
create table public.transactions(id uuid primary key default gen_random_uuid(),payment_id uuid not null references public.payments(id),gateway_event_id text unique,status text not null,amount bigint not null,created_at timestamptz not null default now());
create table public.processed_webhooks(id text primary key,created_at timestamptz not null default now());
create table public.reports(id uuid primary key default gen_random_uuid(),property_id text references public.properties(id) on delete set null,reporter_id uuid not null references public.profiles(id),reason text not null,details text not null default '' check(char_length(details)<=1500),status text not null default 'Open' check(status in ('Open','Resolved')),created_at timestamptz not null default now());
create table public.reviews(id uuid primary key default gen_random_uuid(),author_id uuid not null references public.profiles(id),seller_id uuid not null references public.profiles(id),payment_id uuid not null unique references public.payments(id),rating integer not null check(rating between 1 and 5),text text not null check(char_length(text)<=2000),created_at timestamptz not null default now());
-- Auth profile bootstrap. Clients cannot assign Admin or verification.
create function public.create_profile() returns trigger language plpgsql security definer set search_path=public as $$begin
 insert into public.profiles(id,name,email,role) values(new.id,coalesce(nullif(left(new.raw_user_meta_data->>'name',100),''),'Pavera member'),coalesce(new.email,''),case when new.raw_user_meta_data->>'role' in ('Buyer','Seller','Agent') then new.raw_user_meta_data->>'role' else 'Buyer' end);return new;end$$;
create trigger on_user_created after insert on auth.users for each row execute function public.create_profile();
create function public.protect_profile() returns trigger language plpgsql as $$begin
 if auth.uid() is not null and not public.is_admin() and (new.verified<>old.verified or new.id<>old.id or (new.role='Admin' and old.role<>'Admin') or new.email<>old.email) then raise exception 'Protected account fields cannot be changed';end if;return new;end$$;
create trigger protect_profile before update on public.profiles for each row execute function public.protect_profile();
create function public.validate_property() returns trigger language plpgsql security definer set search_path=public as $$declare owner public.profiles;begin
 if auth.uid() is not null and not public.is_admin() then
  if new.owner_id<>auth.uid() then raise exception 'You can manage only your own listings';end if;
  if tg_op='INSERT' and (new.verified or new.featured or new.status not in ('Draft','Under Review')) then raise exception 'New listings require moderation';end if;
  if tg_op='UPDATE' then
   if new.owner_id<>old.owner_id or new.verified<>old.verified or new.featured<>old.featured then raise exception 'Moderation fields are protected';end if;
   if old.status in ('Draft','Under Review','Rejected') and new.status in ('For Sale','For Rent') then raise exception 'Approval required';end if;
   if new.details is distinct from old.details and new.status in ('For Sale','For Rent') then new.status='Under Review';new.verified=false;end if;
  end if;
 end if;
 if new.status<>'Draft' then
  if not ((new.details->>'price')::numeric>0 and (new.details->>'area')::numeric>0) then raise exception 'A positive price and area are required';end if;
  if char_length(coalesce(new.details->>'city',''))<2 or char_length(coalesce(new.details->>'description',''))<30 then raise exception 'Complete city and description';end if;
  if coalesce(new.details->>'pin','') !~ '^\d{6}$' then raise exception 'Invalid PIN';end if;
  if jsonb_array_length(coalesce(new.details->'photos','[]')) not between 1 and 10 then raise exception '1–10 photos are required';end if;
 end if;
 select * into owner from public.profiles where id=new.owner_id;
 new.details=new.details||jsonb_build_object('seller',owner.name,'sellerPhoto',owner.photo,'ownerId',new.owner_id,'demo',false,'verified',new.verified,'featured',new.featured,'status',new.status);
 new.updated_at=now();return new;end$$;
create trigger validate_property before insert or update on public.properties for each row execute function public.validate_property();
create function public.sync_property_relations() returns trigger language plpgsql security definer set search_path=public as $$begin
 delete from public.property_images where property_id=new.id;
 insert into public.property_images(property_id,url,position,is_primary) select new.id,v.value #>> '{}',(v.ordinality-1)::integer,v.ordinality=1 from jsonb_array_elements(coalesce(new.details->'photos','[]')) with ordinality as v(value,ordinality) where jsonb_typeof(v.value)='string';
 delete from public.property_amenities where property_id=new.id;
 insert into public.property_amenities select new.id,a.name from public.amenities a where a.name in(select jsonb_array_elements_text(coalesce(new.details->'amenities','[]')));
 if tg_op='INSERT' or new.status<>old.status then insert into public.notifications(user_id,title,body,type,property_id) values(new.owner_id,'Listing update',new.title||' · '||new.status,'listing',new.id);end if;return new;end$$;
create trigger sync_property_relations after insert or update on public.properties for each row execute function public.sync_property_relations();
create function public.message_guard() returns trigger language plpgsql security definer set search_path=public as $$declare target uuid;begin
 if (select count(*) from public.messages where sender_id=new.sender_id and created_at>now()-interval '30 seconds')>=15 then raise exception 'Please wait before sending more messages';end if;
 select case when buyer_id=new.sender_id then seller_id else buyer_id end into target from public.conversations where id=new.conversation_id;
 insert into public.notifications(user_id,title,body,type) values(target,'A new conversation awaits',left(new.text,160),'message');return new;end$$;
create trigger message_guard after insert on public.messages for each row execute function public.message_guard();
create function public.comment_guard() returns trigger language plpgsql security definer set search_path=public as $$begin
 if (select count(*) from public.comments where user_id=new.user_id and created_at>now()-interval '1 minute')>=10 then raise exception 'Please wait before posting again';end if;
 select name into new.name from public.profiles where id=new.user_id;return new;end$$;
create trigger comment_guard before insert on public.comments for each row execute function public.comment_guard();
-- Every data entity is secured. The service role is kept only in Edge Function secrets.
do $$declare t text;begin foreach t in array array['profiles','admins','categories','properties','property_images','amenities','property_amenities','saved_properties','likes','comments','conversations','messages','notifications','payments','transactions','processed_webhooks','reports','reviews'] loop execute format('alter table public.%I enable row level security',t);end loop;end$$;
create policy profile_read on public.profiles for select using(id=auth.uid() or public.is_admin());
create policy profile_update on public.profiles for update using(id=auth.uid() or public.is_admin()) with check(id=auth.uid() or public.is_admin());
create policy admin_read on public.admins for select using(user_id=auth.uid());
create policy categories_read on public.categories for select using(true);
create policy categories_admin on public.categories for all using(public.is_admin()) with check(public.is_admin());
create policy properties_read on public.properties for select using(status in ('For Sale','For Rent','Sold','Rented') or owner_id=auth.uid() or public.is_admin());
create policy properties_insert on public.properties for insert with check(owner_id=auth.uid() or public.is_admin());
create policy properties_update on public.properties for update using(owner_id=auth.uid() or public.is_admin()) with check(owner_id=auth.uid() or public.is_admin());
create policy properties_delete on public.properties for delete using(owner_id=auth.uid() or public.is_admin());
create policy images_read on public.property_images for select using(exists(select 1 from public.properties p where p.id=property_id));
create policy amenities_read on public.amenities for select using(true);
create policy property_amenities_read on public.property_amenities for select using(exists(select 1 from public.properties p where p.id=property_id));
create policy saved_private on public.saved_properties for all using(user_id=auth.uid()) with check(user_id=auth.uid() and exists(select 1 from public.properties p where p.id=property_id));
create policy likes_read on public.likes for select using(user_id=auth.uid());
create policy likes_insert on public.likes for insert with check(user_id=auth.uid());
create policy likes_delete on public.likes for delete using(user_id=auth.uid());
create policy comments_read on public.comments for select using(exists(select 1 from public.properties p where p.id=property_id));
create policy comments_insert on public.comments for insert with check(user_id=auth.uid() and exists(select 1 from public.properties p where p.id=property_id));
create policy comments_delete on public.comments for delete using(user_id=auth.uid() or public.is_admin());
create policy conversations_read on public.conversations for select using(auth.uid() in(buyer_id,seller_id));
create policy conversations_insert on public.conversations for insert with check(buyer_id=auth.uid() and exists(select 1 from public.properties p where p.id=property_id and p.owner_id=seller_id and p.status in('For Sale','For Rent')));
create policy conversations_update on public.conversations for update using(auth.uid() in(buyer_id,seller_id)) with check(auth.uid() in(buyer_id,seller_id));
create policy conversations_delete on public.conversations for delete using(auth.uid() in(buyer_id,seller_id));
create function public.protect_conversation() returns trigger language plpgsql as $$begin if new.buyer_id<>old.buyer_id or new.seller_id<>old.seller_id or new.property_id<>old.property_id then raise exception 'Conversation members cannot change';end if;return new;end$$;
create trigger protect_conversation before update on public.conversations for each row execute function public.protect_conversation();
create policy messages_read on public.messages for select using(exists(select 1 from public.conversations c where c.id=conversation_id and auth.uid() in(c.buyer_id,c.seller_id)));
create policy messages_insert on public.messages for insert with check(sender_id=auth.uid() and not read and exists(select 1 from public.conversations c where c.id=conversation_id and auth.uid() in(c.buyer_id,c.seller_id)));
create policy messages_update on public.messages for update using(sender_id<>auth.uid() and exists(select 1 from public.conversations c where c.id=conversation_id and auth.uid() in(c.buyer_id,c.seller_id))) with check(sender_id<>auth.uid());
create function public.protect_message() returns trigger language plpgsql as $$begin if new.sender_id<>old.sender_id or new.text<>old.text or new.conversation_id<>old.conversation_id or new.attachment is distinct from old.attachment then raise exception 'Message content cannot change';end if;return new;end$$;
create trigger protect_message before update on public.messages for each row execute function public.protect_message();
create policy notifications_read on public.notifications for select using(user_id=auth.uid());
create policy notifications_update on public.notifications for update using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy notifications_delete on public.notifications for delete using(user_id=auth.uid());
create policy payments_read on public.payments for select using(auth.uid() in(buyer_id,seller_id) or public.is_admin());
create policy transactions_read on public.transactions for select using(exists(select 1 from public.payments p where p.id=payment_id));
create policy reports_insert on public.reports for insert with check(reporter_id=auth.uid() and status='Open');
create policy reports_read on public.reports for select using(reporter_id=auth.uid() or public.is_admin());
create policy reports_update on public.reports for update using(public.is_admin()) with check(public.is_admin());
create policy reviews_read on public.reviews for select using(true);
create policy reviews_insert on public.reviews for insert with check(author_id=auth.uid() and exists(select 1 from public.payments p where p.id=payment_id and p.buyer_id=auth.uid() and p.seller_id=reviews.seller_id and p.status='Successful'));
-- Atomic webhook application: verified Edge Function only, idempotent event handling.
create function public.apply_payment_event(event_id text,payment_id uuid,next_status text,paid_id text,paid_method text,expected_amount bigint) returns void language plpgsql security definer set search_path=public as $$declare p public.payments;begin
 if exists(select 1 from public.processed_webhooks where id=event_id) then return;end if;
 select * into p from public.payments where id=payment_id for update;
 if not found or p.amount<>expected_amount then raise exception 'Payment not found or amount mismatch';end if;
 if p.status='Refunded' or (p.status='Successful' and next_status not in('Refunded','Successful')) then return;end if;
 update public.payments set status=next_status,gateway_payment_id=coalesce(paid_id,gateway_payment_id),method=coalesce(paid_method,method),updated_at=now() where id=p.id;
 insert into public.transactions(payment_id,gateway_event_id,status,amount) values(p.id,event_id,next_status,expected_amount);
 insert into public.processed_webhooks(id) values(event_id);
 insert into public.notifications(user_id,title,body,type,property_id) values(p.buyer_id,'Payment '||lower(next_status),p.property_title||' · '||next_status,'payment',p.property_id);
end$$;
revoke all on function public.apply_payment_event(text,uuid,text,text,text,bigint) from public,anon,authenticated;
grant execute on function public.apply_payment_event(text,uuid,text,text,text,bigint) to service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('property-images','property-images',true,10485760,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy image_public_read on storage.objects for select using(bucket_id='property-images');
create policy image_owner_upload on storage.objects for insert to authenticated with check(bucket_id='property-images' and (storage.foldername(name))[1]=auth.uid()::text);
create policy image_owner_delete on storage.objects for delete to authenticated using(bucket_id='property-images' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin()));
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.payments;
