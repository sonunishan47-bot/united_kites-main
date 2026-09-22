-- United Kites — ZATCA, van inventory, wholesale SKUs
-- Run in the Supabase SQL editor for project obtporpfzgkpqrdbqjsm.

create table if not exists public.items (
  id uuid primary key,
  sku text not null unique,
  name text not null,
  department text not null default 'other',
  category text,
  size text default '',
  color text default '',
  volume text default '',
  unit text not null default 'pcs',
  purchase_cost numeric(12,2) not null default 0,
  selling_price numeric(12,2) not null default 0,
  price numeric(12,2),
  units_per_carton numeric(12,2) not null default 12,
  carton_price numeric(12,2) not null default 0,
  tax_rate numeric(5,2) not null default 15,
  updated_at timestamptz not null default now()
);

create table if not exists public.stock (
  item_id uuid not null references public.items(id) on delete cascade,
  location text not null,
  quantity numeric(12,2) not null default 0,
  reorder_level numeric(12,2) not null default 5,
  updated_at timestamptz not null default now(),
  primary key (item_id, location)
);

create table if not exists public.stock_movements (
  id uuid primary key,
  item_id uuid not null references public.items(id) on delete cascade,
  location text not null,
  delta numeric(12,2) not null,
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.invoices (
  id uuid primary key,
  invoice_no text not null unique,
  doc_type text not null default 'taxInvoice',
  customer_name text not null,
  customer_phone text,
  customer_trn text,
  notes text,
  subtotal numeric(12,2) not null default 0,
  tax_total numeric(12,2) not null default 0,
  discount numeric(12,2) not null default 0,
  grand_total numeric(12,2) not null default 0,
  status text not null default 'paid',
  created_at timestamptz not null default now(),
  location text not null default 'van1',
  seller_name text,
  vat_trn text,
  cr_number text,
  zatca_qr text,
  original_invoice_id uuid,
  original_invoice_no text,
  submitted boolean not null default true,
  created_by text
);

create table if not exists public.invoice_lines (
  id uuid primary key,
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  item_id uuid,
  item_name text not null,
  sku text,
  quantity numeric(12,2) not null,
  unit_price numeric(12,2) not null,
  tax_rate numeric(5,2) not null default 15,
  line_total numeric(12,2) not null,
  billing_unit text not null default 'piece',
  pieces numeric(12,2) not null default 0,
  variant text
);

create table if not exists public.van_loads (
  id uuid primary key,
  van text not null,
  total_cost numeric(12,2) not null default 0,
  total_sell numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.van_load_lines (
  id text primary key,
  load_id uuid not null references public.van_loads(id) on delete cascade,
  item_id uuid,
  sku text,
  name text,
  quantity numeric(12,2) not null,
  purchase_cost numeric(12,2) not null default 0,
  selling_price numeric(12,2) not null default 0
);

create table if not exists public.shop_settings (
  id int primary key default 1,
  shop_name text,
  address text,
  phone text,
  vat_trn text,
  gstin text,
  cr_number text,
  footer_note text,
  paper text default 'thermal80',
  admin_pin text default '246810',
  vat_rate numeric(5,2) default 15
);

alter table public.items enable row level security;
alter table public.stock enable row level security;
alter table public.stock_movements enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_lines enable row level security;
alter table public.van_loads enable row level security;
alter table public.van_load_lines enable row level security;
alter table public.shop_settings enable row level security;

drop policy if exists items_all on public.items;
create policy items_all on public.items for all using (true) with check (true);
drop policy if exists stock_all on public.stock;
create policy stock_all on public.stock for all using (true) with check (true);
drop policy if exists movements_all on public.stock_movements;
create policy movements_all on public.stock_movements for all using (true) with check (true);
drop policy if exists invoices_all on public.invoices;
create policy invoices_all on public.invoices for all using (true) with check (true);
drop policy if exists invoice_lines_all on public.invoice_lines;
create policy invoice_lines_all on public.invoice_lines for all using (true) with check (true);
drop policy if exists van_loads_all on public.van_loads;
create policy van_loads_all on public.van_loads for all using (true) with check (true);
drop policy if exists van_load_lines_all on public.van_load_lines;
create policy van_load_lines_all on public.van_load_lines for all using (true) with check (true);
drop policy if exists shop_settings_all on public.shop_settings;
create policy shop_settings_all on public.shop_settings for all using (true) with check (true);

alter table public.invoices add column if not exists customer_id uuid;
alter table public.invoices add column if not exists amount_paid numeric(12,2) default 0;
alter table public.invoices add column if not exists shop_name text;
alter table public.shop_settings add column if not exists partner_pin text default '135790';
alter table public.shop_settings add column if not exists commission_rate numeric(5,2) default 2;
alter table public.shop_settings add column if not exists partner_share_pct numeric(5,2) default 50;
alter table public.shop_settings add column if not exists email text default '';
alter table public.shop_settings add column if not exists printer_name text default '';
alter table public.shop_settings add column if not exists printer_mac text default '';
alter table public.shop_settings add column if not exists auto_print boolean default false;
alter table public.shop_settings add column if not exists shop_name_ar text default '';
alter table public.shop_settings add column if not exists phone2 text default '';
alter table public.shop_settings add column if not exists building_no text default '';
alter table public.shop_settings add column if not exists zip_code text default '';
alter table public.shop_settings add column if not exists city text default '';
alter table public.shop_settings add column if not exists country text default '';
alter table public.shop_settings add column if not exists pincode text default '';
alter table public.shop_settings add column if not exists business_description text default '';
alter table public.shop_settings add column if not exists business_type text default 'wholesale';
alter table public.shop_settings add column if not exists business_category text default '';
alter table public.shop_settings add column if not exists books_beginning text default '';
alter table public.shop_settings add column if not exists logo_base64 text default '';
alter table public.shop_settings add column if not exists signature_base64 text default '';
alter table public.shop_settings add column if not exists options jsonb default '{}'::jsonb;

create table if not exists public.customers (
  id uuid primary key,
  name text not null,
  phone text,
  shop_name text,
  cr_number text,
  vat_number text,
  lat double precision default 0,
  lng double precision default 0,
  address text
);

create table if not exists public.payments (
  id uuid primary key,
  customer_id uuid not null,
  amount numeric(12,2) not null,
  method text default 'cash',
  invoice_id uuid,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.van_expenses (
  id uuid primary key,
  van text not null,
  category text not null,
  amount numeric(12,2) not null,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.promo_rules (
  id uuid primary key,
  name text not null,
  min_pieces numeric(12,2) not null default 0,
  discount_pct numeric(5,2) not null default 0,
  sample_qty numeric(12,2) not null default 0
);

alter table public.customers enable row level security;
alter table public.payments enable row level security;
alter table public.van_expenses enable row level security;
alter table public.promo_rules enable row level security;
alter table public.invoices add column if not exists uuid text;
alter table public.invoices add column if not exists icv integer default 0;
alter table public.invoices add column if not exists pih text;
alter table public.invoices add column if not exists invoice_hash text;
alter table public.invoices add column if not exists buyer_cr text;
alter table public.invoices add column if not exists buyer_vat text;
alter table public.customers add column if not exists credit_limit numeric(12,2) default 0;

drop policy if exists customers_all on public.customers;
create policy customers_all on public.customers for all using (true) with check (true);
drop policy if exists payments_all on public.payments;
create policy payments_all on public.payments for all using (true) with check (true);
drop policy if exists van_expenses_all on public.van_expenses;
create policy van_expenses_all on public.van_expenses for all using (true) with check (true);
drop policy if exists promo_rules_all on public.promo_rules;
create policy promo_rules_all on public.promo_rules for all using (true) with check (true);

create table if not exists public.visit_logs (
  id uuid primary key,
  customer_id text not null,
  van text not null default 'van1',
  outcome text not null default 'nonsale',
  reason text,
  lat numeric(10,6) default 0,
  lng numeric(10,6) default 0,
  invoice_id text,
  created_at timestamptz not null default now()
);

alter table public.visit_logs enable row level security;
drop policy if exists visit_logs_all on public.visit_logs;
create policy visit_logs_all on public.visit_logs for all using (true) with check (true);

alter table public.invoices add column if not exists gps_lat numeric(10,6) default 0;
alter table public.invoices add column if not exists gps_lng numeric(10,6) default 0;
alter table public.invoices add column if not exists customer_signature text;
alter table public.invoices add column if not exists print_count integer default 0;
alter table public.invoices add column if not exists return_kind text;
alter table public.van_loads add column if not exists inbound boolean default true;

create table if not exists public.ops_sync (
  id text primary key,
  body jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.ops_sync enable row level security;
drop policy if exists ops_sync_all on public.ops_sync;
create policy ops_sync_all on public.ops_sync for all using (true) with check (true);

