-- Studio Luar Pro — criação das tabelas (Prioridade 1 do CLAUDE.md)
-- Rodar no Supabase SQL Editor do projeto etjsjwpoptrwmxodtknh

-- Produtos (base)
create table if not exists produtos (
  id text primary key,
  name text not null,
  brand text,
  cat text,
  notes text,
  created_at timestamptz default now()
);

-- Variações (filha de produtos)
create table if not exists variacoes (
  id text primary key,
  pid text references produtos(id) on delete cascade,
  label text not null,
  sku text unique,
  stock int default 0,
  min_stock int default 5,
  cost numeric(10,2) default 0,
  price numeric(10,2) default 0,
  created_at timestamptz default now()
);

-- Clientes
create table if not exists clientes (
  id text primary key,
  name text not null,
  phone text,
  cpf text,
  email text,
  birthday date,
  notes text,
  debt numeric(10,2) default 0,
  created_at timestamptz default now()
);

-- Vendas
create table if not exists vendas (
  id text primary key,
  cid text references clientes(id),
  cname text,
  items jsonb,
  subtotal numeric(10,2),
  disc numeric(10,2) default 0,
  frt numeric(10,2) default 0,
  frt_amt numeric(10,2) default 0,
  frt_by text default 'cli',
  tax_rate numeric(5,2) default 0,
  tax_amt numeric(10,2) default 0,
  tax_by text default 'loja',
  total numeric(10,2) not null,
  pay text,
  inst int default 1,
  status text default 'paid',
  notes text,
  date timestamptz default now()
);

-- Transações financeiras
create table if not exists transacoes (
  id text primary key,
  type text not null,
  cat text,
  "desc" text,
  amount numeric(10,2),
  pay text,
  sup text,
  date timestamptz default now()
);

-- Contas a pagar
create table if not exists contas (
  id text primary key,
  "desc" text,
  amount numeric(10,2),
  due_date date,
  cat text,
  sup text,
  paid bool default false,
  created_at timestamptz default now()
);

-- Compras
create table if not exists compras (
  id text primary key,
  vid text references variacoes(id),
  vlabel text,
  pid text references produtos(id),
  pname text,
  qty int,
  cost numeric(10,2),
  sup text,
  date date
);

-- Fornecedores
create table if not exists fornecedores (
  id text primary key,
  name text not null,
  contact text,
  phone text,
  email text,
  notes text,
  created_at timestamptz default now()
);

-- RLS + policies de acesso anônimo (ajustar para auth depois)
do $$ declare t text; begin
  foreach t in array array[
    'produtos','variacoes','clientes','vendas',
    'transacoes','contas','compras','fornecedores'
  ] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists "anon_all" on %I', t);
    execute format('create policy "anon_all" on %I for all to anon using (true) with check (true)', t);
  end loop;
end $$;
