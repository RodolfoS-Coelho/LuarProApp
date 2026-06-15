# CLAUDE.md — Studio Luar Pro
> Diretrizes para o Claude Code (VSCode) continuar o projeto de onde parou.
> Leia este arquivo inteiro antes de qualquer alteração.

---

## 1. O que é este projeto

Sistema de PDV e gestão comercial para salão de estética (cílios, esmaltes, pinças, acessórios).
Desenvolvido para **2 usuárias** (dona + sócia) acessando pelo celular e computador.

**Versão atual:** v6 — arquivo único `StudioLuarPro_v6.html`.
O sistema funciona hoje com **localStorage** como banco de dados temporário.
A próxima etapa crítica é migrar para **Supabase** para persistência real e acesso multi-dispositivo.

---

## 2. Stack atual

| Camada | Tecnologia | Observação |
|---|---|---|
| UI | React 18 (UMD via CDN) | Sem build, sem npm |
| JSX | Babel Standalone 7.23 | Compilado no browser |
| Estado | React hooks + localStorage | Migrar para Supabase |
| Estilo | CSS puro (CSS vars + classes) | Tudo no mesmo arquivo |
| Deploy | Arquivo único `.html` | Próximo: Vercel |

**Não há `package.json`, `node_modules` nem bundler.** O arquivo abre direto no browser.

---

## 3. Arquitetura de dados (modelo relacional atual)

```
produtos (prods)
  id, name, brand, cat, notes

variações (vars)                    ← filha de prods
  id, pid (FK → prods.id),
  label, sku, stock, minStock, cost, price

clientes (clis)
  id, name, phone, cpf, email, birthday, notes, debt

vendas (vendas)
  id, cid, cname,
  items: [{vid, pid, pname, vlabel, sku, price, qty}],
  sub, disc, frt, frtAmt, frtBy,
  taxRate, taxAmt, taxBy,
  total, pay, inst, status, date, notes

transações (txs)
  id, type ('rec' | 'desp'), cat, desc, amount, date, pay?, sup?

contas a pagar (contas)
  id, desc, amount, dueDate, cat, sup, paid (bool)

compras (cprs)                      ← localStorage key: slp_cprs_v6
  id, vid, vlabel, pid, pname, qty, cost, sup, date

fornecedores (forns)                ← localStorage key: slp_forns_v6
  id, name, contact, phone, email, notes
```

**Chaves localStorage em uso:**
```
slp_user_v6, slp_cfg_v6, slp_cats_v6,
slp_prods_v6, slp_vars_v6, slp_clis_v6,
slp_vendas_v6, slp_txs_v6, slp_contas_v6,
slp_cprs_v6, slp_forns_v6,
slp_auth_v6  (array de usuários)
```

---

## 4. Módulos implementados (NÃO reescrever)

| Módulo | Status | Componente |
|---|---|---|
| Login | ✅ | `Login` |
| Dashboard | ✅ | `Dashboard` — 4 cards clicáveis, sem saldos expostos |
| PDV (Vendas) | ✅ | `PDV` — foco auto, bipar SKU, picker variação, recibo auto |
| Compras | ✅ | `Compras` — lote por variação, custo médio ponderado |
| Estoque | ✅ | `Estoque` — visualização de saldo, barra de progresso |
| Clientes | ✅ | `Clientes` — cadastro, histórico, fiado |
| Financeiro | ✅ | `Financeiro` → `FinDesp`, `FinForn`, `FinRel` |
| Relatórios | ✅ | `RelDetalhe` — somente leitura, filtros, impressão/PDF |
| Recibo | ✅ | `Recibo` — imprimir, PDF, WhatsApp |
| Ajustes | ✅ | `Ajustes` → `AjLoja`, `AjFin`, `AjStock`, `AjUsers` |

---

## 5. Próximas tarefas (em ordem de prioridade)

### PRIORIDADE 1 — Migração para Supabase

**Credenciais (já fornecidas pelo cliente):**
```
SUPABASE_URL  = https://etjsjwpoptrwmxodtknh.supabase.co
SUPABASE_KEY  = sb_publishable_1Fl2gc_WopoxFiE3bWMn1Q_uotrPZY0
```

**O que fazer:**
1. Criar as tabelas no Supabase espelhando o modelo da seção 3
2. Substituir o hook `useDB` por chamadas REST ao Supabase (`/rest/v1/`)
3. Manter fallback para localStorage durante transição
4. Implementar autenticação via Supabase Auth (substituir o array `slp_auth_v6`)

**Padrão de chamada REST (sem SDK):**
```javascript
const supa = async (path, opts = {}) => {
  const res = await fetch(`${SUPA_URL}/rest/v1/${path}`, {
    headers: {
      'apikey': SUPA_KEY,
      'Authorization': `Bearer ${SUPA_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
      ...opts.headers,
    },
    ...opts,
  });
  if (!res.ok) throw new Error(await res.text());
  const text = await res.text();
  return text ? JSON.parse(text) : [];
};
```

**SQL para criar as tabelas (rodar no Supabase SQL Editor):**
```sql
-- Produtos (base)
create table produtos (
  id text primary key,
  name text not null,
  brand text,
  cat text,
  notes text,
  created_at timestamptz default now()
);

-- Variações (filha de produtos)
create table variacoes (
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
create table clientes (
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
create table vendas (
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
create table transacoes (
  id text primary key,
  type text not null,
  cat text,
  desc text,
  amount numeric(10,2),
  pay text,
  sup text,
  date timestamptz default now()
);

-- Contas a pagar
create table contas (
  id text primary key,
  desc text,
  amount numeric(10,2),
  due_date date,
  cat text,
  sup text,
  paid bool default false,
  created_at timestamptz default now()
);

-- Compras
create table compras (
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
create table fornecedores (
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
    execute format('create policy "anon_all" on %I for all to anon using (true) with check (true)', t);
  end loop;
end $$;
```

### PRIORIDADE 2 — Deploy Vercel + GitHub

1. Criar repositório GitHub com o arquivo renomeado para `index.html`
2. Conectar ao Vercel (plano free)
3. Configurar variáveis de ambiente no Vercel para as credenciais Supabase
4. URL pública acessível pelos celulares das 2 usuárias

### PRIORIDADE 3 — Funcionalidades pendentes

- [ ] **Leitor de código de barras real** — integrar `ZXing-js` (funciona em todos os browsers, não só Chromium)
- [ ] **DRE simplificado** — receitas − despesas = lucro, por período, com gráfico
- [ ] **Controle de fiado por cliente** — tela dedicada com histórico de débitos/créditos
- [ ] **Notificação de aniversário** — alerta no acesso do dia
- [ ] **Backup/exportação** — botão para exportar dados como JSON ou CSV

---

## 6. Regras de negócio críticas (não alterar)

1. **Produto → Variação é 1:N.** Nunca misturar dados de estoque/preço no produto base.
2. **SKU é único por variação.** Ao bipar código de barras no PDV, busca por SKU exato em `vars`.
3. **Custo médio ponderado:** ao registrar compra:
   `novo_custo = (custo_atual × estoque_atual + custo_compra × qty) / (estoque_atual + qty)`
4. **Venda finalizada = atômica:** salvar + baixar estoque + lançar tx financeira + limpar form — tudo síncrono, sem estados intermediários.
5. **Relatórios são somente leitura.** Zero lançamentos financeiros na tela de relatórios.
6. **Contas a pagar ≠ despesa efetivada.** Só viram `txs` quando botão "Efetivar" é clicado.
7. **Privacidade no Dashboard:** não exibir saldos totais, fiado total nem receita do mês. Só contagens.

---

## 7. Padrões de código

### Hook de persistência local
```javascript
function useDB(k, init) {
  const [v, set] = useState(() => {
    try { const s = localStorage.getItem(k); return s ? JSON.parse(s) : init; }
    catch { return init; }
  });
  const save = useCallback(fn => {
    set(prev => {
      const next = typeof fn === 'function' ? fn(prev) : fn;
      try { localStorage.setItem(k, JSON.stringify(next)); } catch {}
      return next;
    });
  }, [k]);
  return [v, save];
}
```

### IDs e SKUs
```javascript
const genId  = () => Date.now().toString(36) + Math.random().toString(36).slice(2,6);
const genSKU = (name = '') =>
  (name.replace(/[^A-Za-z]/g,'').toUpperCase().slice(0,3) || 'PRD')
  + '-' + Math.floor(Math.random()*9000+1000);
```

### CSS vars disponíveis globalmente
```
--rose, --rose-d, --rose-l, --rose-xl   primário
--gold, --gold-l                         destaque
--green, --gl                            sucesso
--red, --rl                              erro
--blue, --bl                             info
--ink, --ink2, --ink3                    textos
--bg, --white, --border                  backgrounds
--sh, --shm                              sombras
```

### Classes de botão
```
.btn.brose    primário (rosa gradiente)
.btn.bgreen   confirmar
.btn.bred     perigo/deletar
.btn.bghost   neutro/bordas
.btn.bsoft    suave (rosa claro)
.btn.bsm      pequeno
.btn.bxs      mini
.btn.bfull    largura 100%
```

---

## 8. O que NÃO fazer

- ❌ Não instalar npm/bundler — o projeto usa CDN intencionalmente
- ❌ Não criar múltiplos arquivos sem necessidade — manter como `index.html` único
- ❌ Não usar `async/await` em event handlers sem `try/catch`
- ❌ **Nunca escrever `borderRadius:var='...'` em objetos de estilo JSX** — foi o bug que quebrou a v5
- ❌ Não colocar lançamentos financeiros dentro dos componentes de relatório
- ❌ Não expor saldos financeiros totais no Dashboard
- ❌ Não quebrar o fluxo atômico do PDV

---

## 9. Estrutura do arquivo `index.html`

```
index.html
├── <style>          CSS com vars e classes utilitárias
└── <script babel>   Único bloco React
    ├── Helpers      fmt, fmtD, today, nowISO, genId, genSKU, useDB
    ├── Auth         loadU(), saveU(), AUTH_KEY
    ├── Constants    CFG0, CATS0, SP, SV, SC (seeds)
    ├── Components
    │   ├── Modal, Avatar, Login, Recibo, ClientForm
    │   ├── Dashboard
    │   ├── PDV
    │   ├── Compras
    │   ├── Estoque
    │   ├── Clientes
    │   ├── Financeiro → FinDesp, FinForn, FinRel → RelDetalhe
    │   └── Ajustes   → AjLoja, AjFin, AjStock, AjUsers
    └── App          root com todos os estados globais via useDB
```

---

## 10. Checklist antes de cada commit

- [ ] Abre no browser sem erros no console?
- [ ] PDV finaliza uma venda sem travar?
- [ ] Recibo aparece automaticamente após a venda?
- [ ] Formulário do PDV limpa após confirmar?
- [ ] Estoque baixou corretamente nas variações?
- [ ] Nenhum `borderRadius:var=` ou atribuição dentro de objeto de estilo JSX?
- [ ] Número de backticks é par no script inteiro?
- [ ] `&amp;` usado no lugar de `&` em textos JSX (ex: `&amp;` em vez de `&`)?
- [ ] Testou no mobile (viewport 390px)?
