# Lumiq — Phase-wise Implementation Plan
# For use with Claude Code (Autonomous Build Agent)

## CRITICAL RULES FOR ALL PHASES

These rules apply to every line of code written. Never violate them.

1. **Tech stack is locked.** Backend: Python 3.11 + FastAPI. Frontend: Next.js 14 App Router + TypeScript + Tailwind CSS. DB: Supabase. Vector DB: ChromaDB in-process. Embeddings: `sentence-transformers/all-MiniLM-L6-v2`. LLM: Groq API (primary) or Gemini API (fallback). Do not introduce any other technology.

2. **Free-tier only.** No OpenAI API. No paid embeddings. No paid vector DB. No paid auth beyond Supabase free tier.

3. **No unsafe code execution.** The execution engine uses Python `exec()` with a restricted `__builtins__` dict. No Docker. No subprocess sandbox. Timeout enforced via threading.

4. **Every answer comes from executed code.** The LLM never fabricates statistics. If execution fails after retries, return a rejection response.

5. **RAG is always used.** Every `/chat` request must retrieve ChromaDB context before LLM code generation. No bypass.

6. **UI must replicate ChatGPT layout.** Left sidebar (chat list) + main chat panel + bottom input bar. Non-negotiable.

7. **All 6 processing phases must animate in the UI** during a query: "Understanding dataset…" → "Retrieving context…" → "Generating analysis…" → "Executing code…" → "Evaluating result…" → "Preparing response…"

8. **Strict chat isolation.** No cross-chat data leakage. Dataset, messages, and ChromaDB collection are scoped per chat.

9. **Commit strategy: minimum 70 commits.** Each commit is small and atomic. Follow commit naming in each phase below exactly.

10. **Reference these files at all times:** `idea.md`, `ErDiagram.md`, `classDiagram.md`, `sequenceDiagram.md`, `useCaseDiagram.md`.

---

## PHASE 0 — Project Setup and Scaffolding

**Goal:** Monorepo structure, dependency files, linting configs, environment setup. Zero production logic.

### Steps

#### Step 0.1 — Initialize Monorepo
```
lumiq/
├── backend/
├── frontend/
├── .env.example
└── README.md
```
- Create top-level `README.md` with project name "Lumiq", one-line description, and "See PHASES.md for build instructions"
- Create `.env.example` with ALL required env vars (no values, just keys + comments)

```env
# Supabase
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# LLM (Groq free tier - https://console.groq.com)
LLM_API_KEY=
LLM_MODEL=llama3-8b-8192
LLM_BASE_URL=https://api.groq.com/openai/v1

# App
UPLOAD_DIR=./data/uploads
CHROMA_PERSIST_DIR=./data/chroma
MAX_FILE_SIZE_MB=50
EXECUTION_TIMEOUT_SECONDS=10
MAX_RETRY_COUNT=2

# Frontend
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
```

**Commit:** `chore: initialize lumiq monorepo structure`

---

#### Step 0.2 — Backend Scaffold

Create `backend/` directory structure:
```
backend/
├── main.py
├── config.py
├── requirements.txt
├── routers/
│   ├── __init__.py
│   ├── upload.py
│   └── chat.py
├── services/
│   ├── __init__.py
│   ├── dataset_manager.py
│   ├── chat_manager.py
│   ├── rag_service.py
│   ├── code_generator.py
│   ├── execution_engine.py
│   ├── evaluator.py
│   ├── explanation.py
│   ├── llm_client.py
│   ├── log_service.py
│   └── orchestrator.py
├── models/
│   ├── __init__.py
│   └── schemas.py
└── db/
    ├── __init__.py
    └── supabase_client.py
```

All service files start as empty stubs with a `# TODO` comment and the class docstring only. Do NOT implement logic yet.

`requirements.txt`:
```
fastapi==0.111.0
uvicorn[standard]==0.29.0
python-multipart==0.0.9
pydantic==2.7.0
pydantic-settings==2.2.1
supabase==2.4.6
chromadb==0.5.0
sentence-transformers==2.7.0
pandas==2.2.2
numpy==1.26.4
httpx==0.27.0
python-dotenv==1.0.1
```

`backend/config.py`:
```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    supabase_url: str
    supabase_anon_key: str
    supabase_service_role_key: str
    llm_api_key: str
    llm_model: str = "llama3-8b-8192"
    llm_base_url: str = "https://api.groq.com/openai/v1"
    upload_dir: str = "./data/uploads"
    chroma_persist_dir: str = "./data/chroma"
    max_file_size_mb: int = 50
    execution_timeout_seconds: int = 10
    max_retry_count: int = 2

    class Config:
        env_file = ".env"

settings = Settings()
```

`backend/main.py` — skeleton with CORS + routers registered:
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from routers import upload, chat

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Services will be initialized here in Phase 5
    yield

app = FastAPI(title="Lumiq API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(upload.router, prefix="/api", tags=["upload"])
app.include_router(chat.router, prefix="/api", tags=["chat"])

@app.get("/health")
async def health():
    return {"status": "ok", "service": "lumiq-api"}
```

**Commit:** `chore: scaffold backend directory structure and stubs`

---

#### Step 0.3 — Frontend Scaffold

Initialize Next.js 14 App Router project:
```bash
npx create-next-app@14 frontend \
  --typescript \
  --tailwind \
  --app \
  --no-src-dir \
  --import-alias "@/*"
```

Create `frontend/` directory structure:
```
frontend/
├── app/
│   ├── layout.tsx
│   ├── page.tsx
│   ├── globals.css
│   ├── login/
│   │   └── page.tsx
│   ├── signup/
│   │   └── page.tsx
│   └── chat/
│       ├── page.tsx
│       └── [id]/
│           └── page.tsx
├── components/
│   ├── Sidebar.tsx
│   ├── ChatPanel.tsx
│   ├── MessageBubble.tsx
│   ├── InputBar.tsx
│   ├── CodeBlock.tsx
│   ├── DataTable.tsx
│   ├── ProcessingPhases.tsx
│   └── UploadModal.tsx
├── lib/
│   ├── supabase.ts
│   └── api.ts
├── types/
│   └── index.ts
├── next.config.js
└── package.json
```

All component files are empty shells that return `null` with a comment. Do NOT implement UI yet.

Install dependencies:
```bash
cd frontend
npm install @supabase/supabase-js @supabase/auth-helpers-nextjs
npm install react-syntax-highlighter @types/react-syntax-highlighter
npm install axios
npm install lucide-react
npm install date-fns
```

**Commit:** `chore: scaffold Next.js 14 frontend with App Router`

---

#### Step 0.4 — TypeScript Types

Implement `frontend/types/index.ts` with ALL shared types:

```typescript
export interface User {
  id: string;
  email: string;
  created_at: string;
}

export interface Chat {
  id: string;
  user_id: string;
  title: string;
  dataset_id: string | null;
  status: 'active' | 'archived';
  created_at: string;
  updated_at: string;
}

export interface Message {
  id: string;
  chat_id: string;
  role: 'user' | 'assistant';
  content: string;
  metadata: AssistantMetadata | null;
  sequence_number: number;
  created_at: string;
}

export interface AssistantMetadata {
  answer: string;
  code: string;
  result: any;
  result_type: 'dataframe' | 'scalar' | 'list' | 'error' | 'rejection';
  reasoning: string;
  assumptions: string[];
  rag_context_used: string[];
  retry_count: number;
}

export interface Dataset {
  id: string;
  chat_id: string;
  filename: string;
  row_count: number;
  column_count: number;
  schema_info: { columns: ColumnInfo[] };
  sample_rows: Record<string, any>[];
  uploaded_at: string;
}

export interface ColumnInfo {
  name: string;
  dtype: string;
  nullable: boolean;
}

export type ProcessingPhase =
  | 'understanding'
  | 'retrieving'
  | 'generating'
  | 'executing'
  | 'evaluating'
  | 'preparing'
  | 'idle';

export const PHASE_LABELS: Record<ProcessingPhase, string> = {
  understanding: 'Understanding dataset…',
  retrieving: 'Retrieving context…',
  generating: 'Generating analysis…',
  executing: 'Executing code…',
  evaluating: 'Evaluating result…',
  preparing: 'Preparing response…',
  idle: '',
};
```

**Commit:** `feat: add shared TypeScript type definitions`

---

#### Step 0.5 — Linting and Formatting Config

Backend (`backend/.flake8`):
```ini
[flake8]
max-line-length = 100
exclude = .git,__pycache__,venv
```

Frontend (`frontend/.eslintrc.json`):
```json
{
  "extends": ["next/core-web-vitals", "next/typescript"],
  "rules": {
    "@typescript-eslint/no-explicit-any": "warn",
    "no-console": "warn"
  }
}
```

Frontend (`frontend/tailwind.config.ts`) — extend with custom colors:
```typescript
// Keep default Tailwind config
// Add custom colors for Lumiq brand
theme: {
  extend: {
    colors: {
      'lumiq-purple': '#7C3AED',
      'lumiq-dark': '#0F0F0F',
      'lumiq-gray': '#1E1E1E',
    }
  }
}
```

**Commit:** `chore: add linting and formatting configuration`

---

#### Step 0.6 — Supabase Schema Migration

Create `backend/db/migrations/001_initial_schema.sql`:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (mirrors auth.users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- Chats table
CREATE TABLE IF NOT EXISTS public.chat (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'New Chat',
    dataset_id UUID,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Messages table
CREATE TABLE IF NOT EXISTS public.message (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chat_id UUID NOT NULL REFERENCES public.chat(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    metadata JSONB,
    sequence_number INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Dataset table
CREATE TABLE IF NOT EXISTS public.dataset (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chat_id UUID NOT NULL REFERENCES public.chat(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    schema_info JSONB NOT NULL DEFAULT '{}',
    sample_rows JSONB NOT NULL DEFAULT '[]',
    summary_stats JSONB NOT NULL DEFAULT '{}',
    chroma_collection_id TEXT NOT NULL,
    row_count INTEGER NOT NULL DEFAULT 0,
    column_count INTEGER NOT NULL DEFAULT 0,
    uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Execution log table
CREATE TABLE IF NOT EXISTS public.execution_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chat_id UUID NOT NULL REFERENCES public.chat(id) ON DELETE CASCADE,
    message_id UUID REFERENCES public.message(id),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user_query TEXT NOT NULL,
    generated_code TEXT NOT NULL,
    execution_output TEXT,
    execution_status TEXT NOT NULL CHECK (execution_status IN ('success','error','timeout','rejected')),
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    execution_time_ms FLOAT,
    executed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_chat_user_id ON public.chat(user_id);
CREATE INDEX idx_chat_updated_at ON public.chat(updated_at DESC);
CREATE INDEX idx_message_chat_id ON public.message(chat_id);
CREATE INDEX idx_message_sequence ON public.message(chat_id, sequence_number);
CREATE INDEX idx_dataset_chat_id ON public.dataset(chat_id);
CREATE INDEX idx_execution_log_chat_id ON public.execution_log(chat_id);

-- RLS Policies
ALTER TABLE public.chat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dataset ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.execution_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own data" ON public.users FOR ALL USING (auth.uid() = id);
CREATE POLICY "Users own chats" ON public.chat FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users own messages" ON public.message FOR ALL USING (
    chat_id IN (SELECT id FROM public.chat WHERE user_id = auth.uid())
);
CREATE POLICY "Users own datasets" ON public.dataset FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users own logs" ON public.execution_log FOR ALL USING (auth.uid() = user_id);

-- Trigger: auto-create public.users on auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email)
    VALUES (NEW.id, NEW.email)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

> **Claude Code instruction:** Run this SQL in Supabase SQL editor. It must be applied before any backend service is tested.

**Commit:** `feat: add Supabase initial schema migration SQL`

---

#### Step 0.7 — Supabase Client Initialization

`backend/db/supabase_client.py`:
```python
from supabase import create_client, Client
from config import settings

def get_supabase_client() -> Client:
    return create_client(settings.supabase_url, settings.supabase_service_role_key)

supabase: Client = get_supabase_client()
```

`frontend/lib/supabase.ts`:
```typescript
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
```

**Commit:** `feat: add Supabase client initialization for backend and frontend`

---

## PHASE 1 — Authentication

**Goal:** Working login, signup, and session management. Protected routes.

---

#### Step 1.1 — Backend Auth Middleware

`backend/routers/auth_middleware.py`:
```python
from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from supabase import Client
from db.supabase_client import supabase

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(security)
) -> dict:
    """
    Verify Supabase JWT token. Returns user dict {id, email}.
    Raises HTTPException 401 if invalid.
    """
    token = credentials.credentials
    try:
        response = supabase.auth.get_user(token)
        if not response.user:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
        return {"id": response.user.id, "email": response.user.email}
    except Exception:
        raise HTTPException(status_code=401, detail="Authentication failed")
```

**Commit:** `feat: add JWT auth middleware for FastAPI`

---

#### Step 1.2 — Frontend Login Page

`frontend/app/login/page.tsx`:
- Dark background matching ChatGPT login aesthetic
- Email + password fields
- "Sign In" button with loading state
- Link to `/signup`
- On success: redirect to `/chat`
- On error: show inline error message below form
- Use `supabase.auth.signInWithPassword()`
- No external UI libraries — pure Tailwind

Exact styles to use:
- Background: `bg-gray-950`
- Card: `bg-gray-900 rounded-xl p-8 w-full max-w-md`
- Input: `bg-gray-800 border border-gray-700 rounded-lg px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-purple-500`
- Button: `bg-purple-600 hover:bg-purple-700 text-white font-medium py-3 px-4 rounded-lg w-full transition-colors`
- Logo text: "Lumiq" in white, font-bold text-2xl, centered

**Commit:** `feat: implement login page with Supabase auth`

---

#### Step 1.3 — Frontend Signup Page

`frontend/app/signup/page.tsx`:
- Same styling as login
- Fields: email, password, confirm password
- Client-side validation: passwords must match; password min 8 chars
- Use `supabase.auth.signUp()`
- On success: redirect to `/chat`
- Show error from Supabase if email already registered

**Commit:** `feat: implement signup page with Supabase auth`

---

#### Step 1.4 — Route Protection

`frontend/app/middleware.ts` (Next.js middleware):
```typescript
import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs';
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export async function middleware(req: NextRequest) {
    const res = NextResponse.next();
    const supabase = createMiddlewareClient({ req, res });
    const { data: { session } } = await supabase.auth.getSession();

    const isAuthPage = req.nextUrl.pathname.startsWith('/login') ||
                       req.nextUrl.pathname.startsWith('/signup');

    if (!session && !isAuthPage) {
        return NextResponse.redirect(new URL('/login', req.url));
    }
    if (session && isAuthPage) {
        return NextResponse.redirect(new URL('/chat', req.url));
    }
    return res;
}

export const config = {
    matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
```

**Commit:** `feat: add route protection middleware for auth`

---

#### Step 1.5 — Session Context Provider

`frontend/app/layout.tsx` — wrap with Supabase session provider:
```typescript
// Use createServerComponentClient for RSC
// Provide session to client components via context
// Dark theme: bg-gray-950 text-white
```

`frontend/lib/auth.ts`:
```typescript
export async function getCurrentUser() { /* supabase.auth.getUser() */ }
export async function signOut() { /* supabase.auth.signOut() then redirect /login */ }
```

**Commit:** `feat: add session provider and auth utilities`

---

## PHASE 2 — Chat UI Shell (No Backend Logic)

**Goal:** Full ChatGPT-style UI layout with hardcoded/mock data. All visual states must work.

---

#### Step 2.1 — Root Layout and Navigation

`frontend/app/layout.tsx`:
- Dark theme globally: `bg-gray-950 text-white min-h-screen`
- No navbar — layout is entirely sidebar + main panel

`frontend/app/page.tsx`:
- Redirect to `/chat` if authenticated, else `/login`

**Commit:** `feat: implement root layout and root redirect`

---

#### Step 2.2 — Sidebar Component

`frontend/components/Sidebar.tsx`:

Layout:
```
┌─────────────────┐
│ Lumiq           │  ← Logo/brand name, top
│                 │
│ + New Chat      │  ← Button, creates new chat
│─────────────────│
│ [Chat Title 1]  │  ← Recent chat, timestamp
│ [Chat Title 2]  │
│ [Chat Title 3]  │
│ ...             │
│─────────────────│
│ user@email.com  │  ← Bottom: user email + sign out
└─────────────────┘
```

Specifications:
- Width: `w-64` (256px), fixed, no collapse in MVP
- Background: `bg-gray-900`
- Border right: `border-r border-gray-800`
- Chat list items: `hover:bg-gray-800 cursor-pointer px-4 py-3 rounded-lg`
- Active chat: `bg-gray-800 border-l-2 border-purple-500`
- "+ New Chat" button: `bg-purple-600 hover:bg-purple-700 text-white text-sm py-2 px-4 rounded-lg w-full`
- Timestamps: relative format using `date-fns` (`formatDistanceToNow`)
- Props: `chats: Chat[], activeChatId: string, onSelectChat, onNewChat, user: User`

**Commit:** `feat: implement Sidebar component with chat list`

---

#### Step 2.3 — Chat Page Layout

`frontend/app/chat/page.tsx`:
- Full viewport flex layout: sidebar (fixed width) + main panel (flex-1)
- Main panel shows "Select a chat or create a new one" when no chat selected
- Loads chat list via `GET /api/chats` on mount
- Handles new chat creation

`frontend/app/chat/[id]/page.tsx`:
- Renders Sidebar + ChatPanel side by side
- Passes `chatId` to ChatPanel
- Loads chat data via `GET /api/chat/{id}` on mount

**Commit:** `feat: implement chat layout with sidebar integration`

---

#### Step 2.4 — ChatPanel Component (Shell)

`frontend/components/ChatPanel.tsx`:

Layout:
```
┌────────────────────────────────┐
│ [Dataset preview card]         │  ← pinned top, only if dataset exists
│────────────────────────────────│
│                                │
│  [messages scroll area]        │
│                                │
│────────────────────────────────│
│ [InputBar]                     │  ← fixed bottom
└────────────────────────────────┘
```

- Messages scroll area: `flex-1 overflow-y-auto px-4 py-6 space-y-6`
- Scroll to bottom on new message: use `useRef` + `scrollIntoView`
- Dataset preview card: shows filename + column count + row count (collapsed by default)
- Empty state: centered text "Upload a CSV to start analyzing your data" with upload icon
- Props: `chatId: string, messages: Message[], dataset: Dataset | null, isLoading: boolean, processingPhase: ProcessingPhase`

**Commit:** `feat: implement ChatPanel layout and scroll behavior`

---

#### Step 2.5 — MessageBubble Component

`frontend/components/MessageBubble.tsx`:

User message:
- Aligned right
- `bg-purple-600 text-white rounded-2xl rounded-tr-sm px-4 py-3 max-w-[75%]`

Assistant message:
- Aligned left
- `bg-gray-800 text-gray-100 rounded-2xl rounded-tl-sm px-4 py-4 max-w-[85%]`
- Sections rendered in order:
  1. **Answer** — `text-white text-base`
  2. **Code Block** — `<CodeBlock>` (always visible)
  3. **Result** — `<DataTable>` or scalar callout
  4. **Reasoning** — collapsible section with chevron icon
  5. **Assumptions** — collapsible list

- Props: `message: Message`

**Commit:** `feat: implement MessageBubble with full response structure`

---

#### Step 2.6 — CodeBlock Component

`frontend/components/CodeBlock.tsx`:
- Import `SyntaxHighlighter` from `react-syntax-highlighter`
- Use `vscDarkPlus` theme
- Language always `python`
- Header bar: "Generated Code" label + copy button (clipboard icon)
- Copy button shows "Copied!" for 2 seconds on click
- Code block max-height: `400px`, vertically scrollable
- Wrapper: `bg-gray-900 rounded-lg overflow-hidden border border-gray-700`

**Commit:** `feat: implement CodeBlock with syntax highlighting and copy`

---

#### Step 2.7 — DataTable Component

`frontend/components/DataTable.tsx`:
- Renders `result` when `result_type === "dataframe"`
- Expects `result` as `{columns: string[], rows: any[][], shape: [number, number]}`
- Table styles:
  - `overflow-x-auto` wrapper
  - Header: `bg-gray-700 text-gray-300 text-xs uppercase`
  - Rows: alternating `bg-gray-800` / `bg-gray-750`
  - Show max 50 rows; if more, show "Showing 50 of N rows" footer
- Scalar result: large centered value in a `bg-gray-700 rounded-lg p-4 text-2xl font-mono` box
- List result: `<ol>` with `list-decimal` styling

**Commit:** `feat: implement DataTable for DataFrame and scalar results`

---

#### Step 2.8 — ProcessingPhases Component

`frontend/components/ProcessingPhases.tsx`:

This is the animated status indicator shown during query processing:

Phases (in order):
1. "Understanding dataset…"
2. "Retrieving context…"
3. "Generating analysis…"
4. "Executing code…"
5. "Evaluating result…"
6. "Preparing response…"

UI:
- Renders as an assistant message bubble with animated content
- Current phase shown with a pulsing dot (CSS animate-pulse in Tailwind)
- Completed phases shown with a checkmark (`✓`) in muted gray
- Current phase text in white/bright
- Upcoming phases not shown (progressive disclosure)
- Animation: fade-in on each phase transition
- Implementation: receive `currentPhase: ProcessingPhase`; derive display from PHASE_LABELS

```tsx
// Example render when phase = 'executing':
// ✓ Understanding dataset
// ✓ Retrieving context
// ✓ Generating analysis
// ● Executing code...   ← pulsing
```

**Commit:** `feat: implement ProcessingPhases animated status component`

---

#### Step 2.9 — InputBar Component

`frontend/components/InputBar.tsx`:
- Fixed bottom of ChatPanel
- Background: `bg-gray-900 border-t border-gray-800 px-4 py-4`
- Textarea (not input): auto-expands up to 5 lines; Enter sends, Shift+Enter = newline
- Send button: purple, disabled when empty or loading
- Upload button: paperclip icon, opens UploadModal, visible only when no dataset uploaded
- Disabled state: when `isLoading === true` — textarea gets `opacity-50 cursor-not-allowed`
- Props: `onSend: (query: string) => void, onUpload: () => void, isLoading: boolean, hasDataset: boolean`

**Commit:** `feat: implement InputBar with send and upload controls`

---

#### Step 2.10 — UploadModal Component

`frontend/components/UploadModal.tsx`:
- Modal overlay: `fixed inset-0 bg-black/70 flex items-center justify-center z-50`
- Modal card: `bg-gray-900 rounded-xl p-8 w-full max-w-md border border-gray-700`
- Drag-and-drop zone: dashed border, changes on hover/drag-over
- File input: hidden, triggered by click on drop zone
- Shows selected filename before upload
- "Upload" button: triggers `POST /upload`
- Loading state: spinner during upload
- Close button (X) in top-right corner
- Error state: shows validation errors inline
- Accepts ONLY `.csv` files (enforced via `accept=".csv"`)

**Commit:** `feat: implement UploadModal with drag-and-drop CSV upload`

---

## PHASE 3 — Backend: Dataset Upload

**Goal:** Fully working CSV upload endpoint with schema extraction and ChromaDB indexing.

---

#### Step 3.1 — Pydantic Models

`backend/models/schemas.py` — implement ALL Pydantic models:

```python
from pydantic import BaseModel
from typing import Any, Optional
from datetime import datetime

class ColumnInfo(BaseModel):
    name: str
    dtype: str
    nullable: bool

class SchemaInfo(BaseModel):
    columns: list[ColumnInfo]

class DatasetResponse(BaseModel):
    id: str
    chat_id: str
    filename: str
    row_count: int
    column_count: int
    schema_info: SchemaInfo
    sample_rows: list[dict[str, Any]]
    uploaded_at: str

class UploadResponse(BaseModel):
    dataset: DatasetResponse
    message: str

class ChatCreateRequest(BaseModel):
    title: str = "New Chat"

class ChatResponse(BaseModel):
    id: str
    user_id: str
    title: str
    dataset_id: Optional[str]
    status: str
    created_at: str
    updated_at: str

class MessageResponse(BaseModel):
    id: str
    chat_id: str
    role: str
    content: str
    metadata: Optional[dict[str, Any]]
    sequence_number: int
    created_at: str

class QueryRequest(BaseModel):
    chat_id: str
    query: str

    class Config:
        str_max_length = 1000

class AssistantResponse(BaseModel):
    answer: str
    code: str
    result: Any
    result_type: str
    reasoning: str
    assumptions: list[str]
    rag_context_used: list[str]
    retry_count: int

class QueryResponse(BaseModel):
    message_id: str
    response: AssistantResponse
    chat_id: str
    created_at: str

class ExecutionResult(BaseModel):
    success: bool
    output: Any
    output_type: str
    error: Optional[str]
    execution_time_ms: float
    serialized_output: str

class EvaluationResult(BaseModel):
    is_valid: bool
    is_relevant: bool
    confidence: float
    reason: str
    should_retry: bool
    suggested_fix: Optional[str]

class CodeGenerationResult(BaseModel):
    code: str
    raw_llm_response: str
```

**Commit:** `feat: implement all Pydantic request/response schemas`

---

#### Step 3.2 — DatasetManager Service

`backend/services/dataset_manager.py` — full implementation:

```python
class DatasetManager:
    def load_csv(self, file_path: str) -> pd.DataFrame:
        """Load CSV. Raise ValueError if empty or no columns."""

    def extract_schema(self, df: pd.DataFrame) -> dict:
        """
        Returns: {
            "columns": [
                {"name": col, "dtype": str(dtype), "nullable": bool(df[col].isna().any())}
                for col, dtype in df.dtypes.items()
            ]
        }
        Include unique_count for object (string) columns with ≤ 20 unique values.
        Include unique_values list for object columns with ≤ 10 unique values.
        """

    def extract_sample_rows(self, df: pd.DataFrame, n: int = 5) -> list[dict]:
        """Return first n rows as list of dicts. Convert NaN to None."""

    def extract_summary_stats(self, df: pd.DataFrame) -> dict:
        """
        Returns df.describe(include='all').to_dict().
        Convert NaN to None for JSON serialization.
        Also include: total_rows, total_columns, memory_usage_bytes.
        """

    def save_dataset_metadata(self, ...) -> dict:
        """INSERT into Supabase dataset table. Return full dataset dict."""

    def get_dataset_by_chat_id(self, chat_id: str) -> dict:
        """SELECT from Supabase. Raise ValueError if not found."""

    def load_dataframe_from_storage(self, storage_path: str) -> pd.DataFrame:
        """Load CSV from disk path. Raise FileNotFoundError if missing."""

    def validate_csv(self, file_path: str) -> tuple[bool, str]:
        """
        Returns (True, "") if valid.
        Returns (False, reason) if: empty file, no columns, parse error,
        more than 500 columns, non-UTF8 encoding.
        """
```

**Commit:** `feat: implement DatasetManager with CSV loading and schema extraction`

---

#### Step 3.3 — RAGService (ChromaDB Integration)

`backend/services/rag_service.py` — full implementation:

```python
import chromadb
from chromadb.utils import embedding_functions

class RAGService:
    def __init__(self, persist_dir: str):
        self.chroma_client = chromadb.PersistentClient(path=persist_dir)
        self.embedding_fn = embedding_functions.SentenceTransformerEmbeddingFunction(
            model_name="sentence-transformers/all-MiniLM-L6-v2"
        )

    def get_or_create_collection(self, collection_id: str):
        return self.chroma_client.get_or_create_collection(
            name=collection_id,
            embedding_function=self.embedding_fn
        )

    def build_documents(self, schema: dict, samples: list, stats: dict) -> list[str]:
        """
        Returns exactly 3 documents:
        1. Schema doc: "Dataset schema:\n" + column list with dtypes + unique values
        2. Sample doc: "Sample data rows:\n" + JSON-like row representations
        3. Stats doc: "Statistical summary:\n" + key stats for numeric columns
        These are the documents embedded into ChromaDB.
        """

    def index_dataset(self, collection_id: str, schema: dict, samples: list, stats: dict):
        """
        Build 3 documents, embed them, add to collection.
        IDs: ["schema", "samples", "stats"]
        """

    def retrieve_context(self, collection_id: str, query: str, n_results: int = 3) -> list[str]:
        """
        Query ChromaDB collection.
        Returns list of document strings (the most relevant schema/sample/stats docs).
        """

    def delete_collection(self, collection_id: str):
        """Delete ChromaDB collection. Used for cleanup."""
```

**Commit:** `feat: implement RAGService with ChromaDB and HuggingFace embeddings`

---

#### Step 3.4 — Upload Router

`backend/routers/upload.py` — full implementation:

```python
@router.post("/upload", response_model=UploadResponse)
async def upload_dataset(
    chat_id: str = Form(...),
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    # services injected via request.app.state
):
    """
    1. Validate file: extension must be .csv, size ≤ MAX_FILE_SIZE_MB
    2. Save file to UPLOAD_DIR/{user_id}/{dataset_id}.csv
    3. Validate CSV (DatasetManager.validate_csv)
    4. Load DataFrame (DatasetManager.load_csv)
    5. Extract schema, samples, stats
    6. Verify chat belongs to user (Supabase lookup)
    7. Save metadata to Supabase (DatasetManager.save_dataset_metadata)
    8. Update chat.dataset_id in Supabase
    9. Create ChromaDB collection and index (RAGService)
    10. Return UploadResponse
    """
```

Error handling:
- 400: file not CSV, CSV invalid, chat not found
- 403: chat belongs to different user
- 409: chat already has a dataset
- 413: file too large
- 500: internal error (log + return generic message)

**Commit:** `feat: implement dataset upload endpoint with full validation`

---

#### Step 3.5 — Service Initialization in main.py

Update `backend/main.py` lifespan to initialize and store services:

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    os.makedirs(settings.upload_dir, exist_ok=True)
    os.makedirs(settings.chroma_persist_dir, exist_ok=True)

    app.state.rag_service = RAGService(persist_dir=settings.chroma_persist_dir)
    app.state.dataset_manager = DatasetManager(supabase=supabase, upload_dir=settings.upload_dir)
    app.state.chat_manager = ChatManager(supabase=supabase)
    # LLM + other services added in Phase 4+
    yield
```

**Commit:** `feat: initialize core services in FastAPI lifespan`

---

#### Step 3.6 — Frontend Upload Integration

`frontend/lib/api.ts` — implement upload function:
```typescript
export async function uploadDataset(chatId: string, file: File, token: string): Promise<DatasetResponse>
```

Connect `UploadModal` to real backend:
- On submit: call `uploadDataset()`
- On success: update parent state with returned `Dataset`; show dataset preview card in ChatPanel
- On error: show error in modal

**Commit:** `feat: connect frontend upload flow to backend API`

---

## PHASE 4 — Chat System (Messages + History)

**Goal:** Create chats, persist messages, load past chats. All without LLM yet.

---

#### Step 4.1 — ChatManager Service

`backend/services/chat_manager.py` — full implementation:

```python
class ChatManager:
    def create_chat(self, user_id: str, title: str = "New Chat") -> dict:
        """INSERT into chat table. Return chat dict."""

    def get_chats_by_user(self, user_id: str) -> list[dict]:
        """SELECT chats WHERE user_id, ORDER BY updated_at DESC."""

    def get_chat_by_id(self, chat_id: str, user_id: str) -> dict:
        """SELECT chat + all messages + dataset info. Raise 404 if not found or wrong user."""

    def add_message(self, chat_id: str, role: str, content: str, metadata: dict = None) -> dict:
        """
        INSERT message.
        sequence_number = max(sequence_number) + 1 for this chat.
        Also UPDATE chat.updated_at = NOW().
        """

    def get_messages_by_chat(self, chat_id: str) -> list[dict]:
        """SELECT messages WHERE chat_id ORDER BY sequence_number ASC."""

    def get_recent_context(self, chat_id: str, n: int = 10) -> list[dict]:
        """Return last n messages as {role, content} dicts for LLM context."""

    def auto_generate_title(self, first_query: str) -> str:
        """
        Truncate first_query to 50 chars.
        If query ends mid-word at truncation point, trim to last complete word.
        Return as chat title.
        """
```

**Commit:** `feat: implement ChatManager with full CRUD and message persistence`

---

#### Step 4.2 — Chat Routers

`backend/routers/chat.py` — implement all endpoints:

```python
# POST /chats — create new chat
@router.post("/chats", response_model=ChatResponse)

# GET /chats — list user's chats
@router.get("/chats", response_model=list[ChatResponse])

# GET /chat/{chat_id} — get full chat with messages
@router.get("/chat/{chat_id}")
# Returns: {chat: ChatResponse, messages: list[MessageResponse], dataset: DatasetResponse | None}

# POST /chat — send query (placeholder until Phase 5)
@router.post("/chat", response_model=QueryResponse)
# For now: persist user message only, return stub assistant response
```

All endpoints use `Depends(get_current_user)` for auth.

**Commit:** `feat: implement chat CRUD endpoints`

---

#### Step 4.3 — Frontend Chat API Integration

`frontend/lib/api.ts` — implement:
```typescript
export async function createChat(token: string): Promise<Chat>
export async function getChats(token: string): Promise<Chat[]>
export async function getChat(chatId: string, token: string): Promise<{chat: Chat, messages: Message[], dataset: Dataset | null}>
export async function sendQuery(chatId: string, query: string, token: string): Promise<QueryResponse>
```

**Commit:** `feat: implement frontend API client functions for chat`

---

#### Step 4.4 — Wire Sidebar to Live Data

Update `frontend/app/chat/page.tsx`:
- On mount: call `getChats()` and populate sidebar
- "+ New Chat" calls `createChat()` and navigates to new chat
- Sidebar chat items navigate to `/chat/{id}`

**Commit:** `feat: connect sidebar to live chat data`

---

#### Step 4.5 — Wire ChatPanel to Live Data

Update `frontend/app/chat/[id]/page.tsx`:
- On mount: call `getChat(id)` and populate messages + dataset
- Scroll to bottom of message list on load
- Send query calls `sendQuery()` (stub response for now)
- User message added optimistically to UI before response

**Commit:** `feat: connect chat panel to live message data`

---

## PHASE 5 — LLM Integration + Code Generation

**Goal:** Full LLM client, prompt engineering, code generation from user queries.

---

#### Step 5.1 — LLMClient Service

`backend/services/llm_client.py`:

```python
class LLMClient:
    """
    Async wrapper around Groq API (OpenAI-compatible endpoint).
    Falls back gracefully if API key invalid.
    """
    def __init__(self, api_key: str, model: str, base_url: str):
        self.api_key = api_key
        self.model = model
        self.base_url = base_url
        self.client = httpx.AsyncClient(timeout=30.0)

    async def complete(
        self,
        messages: list[dict],
        temperature: float = 0.1,
        max_tokens: int = 1000
    ) -> str:
        """
        POST to {base_url}/chat/completions.
        Returns content string from first choice.
        Raises LLMError on API error.
        """

    async def complete_with_retry(
        self,
        messages: list[dict],
        max_attempts: int = 3
    ) -> str:
        """Retry with exponential backoff on rate limit (429) or timeout."""
```

**Commit:** `feat: implement async LLMClient for Groq API`

---

#### Step 5.2 — Code Generation Prompts

`backend/services/code_generator.py`:

System prompt (hardcoded, do not deviate):
```
You are a Python data analysis expert. Your ONLY job is to write Pandas code to answer questions about a given dataset.

RULES:
1. Return ONLY a Python code block. No explanation before or after.
2. The DataFrame is already loaded as variable `df`. Do not load from files.
3. Only use these imports: pandas (as pd), numpy (as np), math, datetime, statistics, re.
4. Store the final result in a variable named `result`.
5. `result` must be a DataFrame, scalar (int/float/str), or list.
6. NEVER use: os, sys, subprocess, open(), exec(), eval(), requests, socket, or any file I/O.
7. NEVER modify the original `df` in place for operations that require the original later.
8. Handle NaN values explicitly where appropriate.
9. If the question cannot be answered with the available columns, raise a ValueError with a clear message.
10. Keep code concise and correct. No comments needed.

Format your response EXACTLY as:
```python
[your code here]
```
```

User prompt format:
```
Dataset Schema:
{formatted_schema}

Retrieved Context:
{rag_context_joined}

Recent Conversation:
{formatted_history}

User Question: {query}

Write Python/Pandas code to answer this question. The DataFrame is loaded as `df`.
```

```python
class CodeGenerator:
    def generate_code(self, query, schema_context, chat_history, dataset_schema) -> CodeGenerationResult:
        """Build prompt, call LLM, extract code block, validate safety."""

    def extract_code_from_response(self, response: str) -> str:
        """
        Strip ```python ... ``` fences.
        If no fences found, return response as-is (LLM sometimes doesn't wrap).
        """

    def validate_code_safety(self, code: str) -> tuple[bool, str]:
        """
        Checks for forbidden patterns using regex.
        Forbidden: import os, import sys, subprocess, open(, requests,
                   socket, __import__, write(, .to_csv, .to_excel,
                   exec(, eval(
        Returns (True, "") if safe, (False, "reason") if unsafe.
        """
```

**Commit:** `feat: implement CodeGenerator with LLM prompts and safety validation`

---

#### Step 5.3 — ExecutionEngine Service

`backend/services/execution_engine.py` — full implementation:

```python
import threading
import traceback
import pandas as pd
import numpy as np
import math
import datetime
import statistics
import re

ALLOWED_BUILTINS = {
    'print': print, 'len': len, 'range': range, 'enumerate': enumerate,
    'zip': zip, 'map': map, 'filter': filter, 'sorted': sorted,
    'list': list, 'dict': dict, 'set': set, 'tuple': tuple,
    'str': str, 'int': int, 'float': float, 'bool': bool,
    'abs': abs, 'round': round, 'min': min, 'max': max, 'sum': sum,
    'isinstance': isinstance, 'type': type, 'hasattr': hasattr,
    'getattr': getattr, 'ValueError': ValueError, 'KeyError': KeyError,
    'TypeError': TypeError, 'None': None, 'True': True, 'False': False,
}

class ExecutionEngine:
    def __init__(self, timeout_seconds: int = 10):
        self.timeout_seconds = timeout_seconds

    def build_safe_globals(self, df: pd.DataFrame) -> dict:
        return {
            '__builtins__': ALLOWED_BUILTINS,
            'pd': pd,
            'np': np,
            'math': math,
            'datetime': datetime,
            'statistics': statistics,
            're': re,
            'df': df.copy(),  # Pass copy to prevent mutation
        }

    def execute(self, code: str, df: pd.DataFrame) -> ExecutionResult:
        """
        1. Check forbidden patterns (final safety gate before exec)
        2. Build safe globals with df injected
        3. Run in thread with timeout
        4. Capture `result` variable from scope
        5. Serialize result
        6. Return ExecutionResult
        """

    def serialize_result(self, result: any) -> tuple[str, str]:
        """
        Returns (serialized: str, type: str)
        DataFrame → ({columns: [...], rows: [[...]], shape: [r, c]}, "dataframe")
        Series → (list representation, "list")
        scalar → (str(value), "scalar")
        None → ("No result returned", "error")
        """

    def _run_with_timeout(self, code: str, scope: dict) -> tuple[bool, any, str]:
        """
        Run exec(code, scope) in a daemon thread.
        thread.join(timeout=self.timeout_seconds).
        If thread still alive → return (False, None, "Execution timeout")
        Returns (success, result_value, error_message)
        """
```

**Commit:** `feat: implement ExecutionEngine with restricted exec and timeout`

---

#### Step 5.4 — Evaluator Service

`backend/services/evaluator.py`:

```python
class Evaluator:
    def evaluate(self, query: str, code: str, result: ExecutionResult) -> EvaluationResult:
        """
        Step 1: Check result.success == True
        Step 2: Check result.output is not None
        Step 3: If result is DataFrame, check it has > 0 rows
        Step 4: LLM relevance check (lightweight prompt):
            "Does this result: {result.serialized_output[:200]}
             answer this question: {query}?
             Reply with only: YES or NO"
        Step 5: Return EvaluationResult
        """

    def should_retry(self, eval_result: EvaluationResult, attempt: int) -> bool:
        """Return True if not valid AND attempt < MAX_RETRY_COUNT (2)."""

    def generate_retry_prompt_suffix(self, code: str, error: str) -> str:
        """
        Returns: "The previous code had this error: {error}
                 Previous code: {code}
                 Fix the error and write corrected code."
        """
```

**Commit:** `feat: implement Evaluator with LLM relevance check and retry logic`

---

#### Step 5.5 — ExplanationService

`backend/services/explanation.py`:

```python
class ExplanationService:
    def format_response(self, query, code, exec_result, eval_result, rag_context) -> dict:
        """
        Returns full AssistantResponse dict:
        {
            "answer": human-readable 1-3 sentence summary derived from result,
            "code": code string (always included),
            "result": serialized result,
            "result_type": exec_result.output_type,
            "reasoning": step-by-step explanation,
            "assumptions": extracted assumptions,
            "rag_context_used": rag_context,
            "retry_count": eval_result retry count
        }
        """

    def generate_answer_summary(self, query: str, result: ExecutionResult) -> str:
        """
        For scalar: "The {query_noun} is {value}."
        For DataFrame: "Found {n} rows matching your query."
        For list: "The result contains {n} items."
        Keep it under 3 sentences. No fabrication.
        """

    def generate_reasoning(self, query: str, code: str, rag_context: list[str]) -> str:
        """
        Explain what the code does in plain English.
        e.g. "I filtered the dataset by [column], then grouped by [column], 
              and computed the [aggregation]."
        """

    def extract_assumptions(self, code: str, schema: dict) -> list[str]:
        """
        Scan code for column name references.
        For each referenced column, note its dtype as an assumption.
        e.g. "Assumed 'revenue' is numeric (float64)"
        """

    def format_error_response(self, query: str, error: str, retry_count: int) -> dict:
        """Return structured rejection with reason and rephrase suggestion."""

    def format_rejection_response(self, query: str, reason: str) -> dict:
        """Return structured rejection when query is unsupported."""
```

**Commit:** `feat: implement ExplanationService for structured response formatting`

---

#### Step 5.6 — ChatOrchestrator

`backend/services/orchestrator.py` — full pipeline implementation:

Exactly follows the sequence diagram in `sequenceDiagram.md` Step 2.

Pipeline:
1. Persist user message
2. Load dataset + DataFrame
3. Load recent context (last 10 messages)
4. RAG retrieval (3 docs from ChromaDB)
5. Generate code (LLM)
6. Safety validate code
7. Execute code
8. Evaluate result
9. Retry loop (max 2, with error context injected)
10. Format explanation
11. Persist assistant message
12. Log execution
13. Return ChatResponse

**Commit:** `feat: implement ChatOrchestrator full pipeline`

---

#### Step 5.7 — Wire /chat Endpoint

Update `backend/routers/chat.py` `POST /chat` to use `ChatOrchestrator`:

```python
@router.post("/chat", response_model=QueryResponse)
async def send_query(
    request: QueryRequest,
    current_user: dict = Depends(get_current_user),
    req: Request = None,
):
    orchestrator = req.app.state.orchestrator
    return await orchestrator.handle_query(
        chat_id=request.chat_id,
        user_id=current_user["id"],
        query=request.query
    )
```

Validation before calling orchestrator:
- Chat must exist and belong to user
- Dataset must be uploaded to chat
- Query must not be empty
- Query must be ≤ 1000 characters

**Commit:** `feat: wire /chat endpoint to full orchestration pipeline`

---

#### Step 5.8 — Update Service Initialization

Update `backend/main.py` lifespan to initialize all remaining services:
- `LLMClient`
- `CodeGenerator`
- `ExecutionEngine`
- `Evaluator`
- `ExplanationService`
- `ExecutionLogService`
- `ChatOrchestrator` (with all dependencies injected)

**Commit:** `feat: initialize all services in FastAPI lifespan`

---

## PHASE 6 — Frontend Query Integration

**Goal:** Connect frontend send query to live backend. Show processing phases. Render full response.

---

#### Step 6.1 — Query State Management

`frontend/app/chat/[id]/page.tsx` — implement query state:

```typescript
const [isLoading, setIsLoading] = useState(false);
const [processingPhase, setProcessingPhase] = useState<ProcessingPhase>('idle');
const [messages, setMessages] = useState<Message[]>([]);
```

Phase simulation (since backend is synchronous, simulate phases on frontend):
```typescript
async function handleSendQuery(query: string) {
    setIsLoading(true);
    // Add user message optimistically
    addUserMessage(query);

    // Simulate phases with delays (each ~0.8s)
    const phases: ProcessingPhase[] = [
        'understanding', 'retrieving', 'generating',
        'executing', 'evaluating', 'preparing'
    ];
    for (const phase of phases) {
        setProcessingPhase(phase);
        await new Promise(r => setTimeout(r, 800));
        // Break early if response received
    }

    // Actual API call runs in parallel
    const response = await sendQuery(chatId, query, token);
    setProcessingPhase('idle');
    setIsLoading(false);
    addAssistantMessage(response);
}
```

> **Implementation note:** In production, phase updates should come from SSE/WebSocket.
> For this MVP, use parallel timer + fetch approach: start timers AND fetch simultaneously;
> stop timers when fetch resolves.

**Commit:** `feat: implement query state management with phase simulation`

---

#### Step 6.2 — Render Full Assistant Response

Update `MessageBubble.tsx` to render all sections of `AssistantMetadata`:

1. **Answer** section — plain text, white
2. **Code** section — `<CodeBlock code={metadata.code} />`
3. **Result** section:
   - `result_type === 'dataframe'` → `<DataTable result={metadata.result} />`
   - `result_type === 'scalar'` → highlighted value box
   - `result_type === 'list'` → ordered list
   - `result_type === 'error'` → red error card
   - `result_type === 'rejection'` → orange rejection card with rephrase suggestion
4. **Reasoning** section — `<details><summary>Reasoning</summary>{metadata.reasoning}</details>` style
5. **Assumptions** section — bulleted list if `assumptions.length > 0`

**Commit:** `feat: render complete structured assistant response in MessageBubble`

---

#### Step 6.3 — Error and Rejection States

Frontend error handling:
- Network error → show "Connection failed. Please check your internet." in chat
- 504 timeout → show "Analysis timed out. Please try again."
- 400 bad request → show backend error message
- Rejection response → render with orange border, "Unable to answer" header, rephrase suggestions

**Commit:** `feat: implement error and rejection state rendering`

---

#### Step 6.4 — Dataset Preview Card

After upload, a dataset preview card is shown pinned at top of ChatPanel:
- Card: `bg-gray-800 rounded-lg p-4 border border-gray-700 mx-4 mt-4`
- Shows: filename, row_count × column_count, list of column names as badges
- Toggle expand/collapse to show sample rows table (collapsed by default)

**Commit:** `feat: implement dataset preview card in ChatPanel`

---

## PHASE 7 — ExecutionLogService + Logging

---

#### Step 7.1 — ExecutionLogService

`backend/services/log_service.py` — full implementation:

```python
class ExecutionLogService:
    def log_execution(
        self,
        chat_id: str,
        message_id: str,
        user_id: str,
        query: str,
        code: str,
        output: str,
        status: str,
        error: str | None,
        retry_count: int,
        exec_time: float
    ) -> None:
        """INSERT into execution_log table. Never raise — log errors silently."""

    def get_logs_by_chat(self, chat_id: str) -> list[dict]:
        """SELECT logs WHERE chat_id ORDER BY executed_at DESC."""
```

**Commit:** `feat: implement ExecutionLogService for audit logging`

---

#### Step 7.2 — Error Logging Middleware

Add FastAPI exception handler middleware to `backend/main.py`:

```python
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Log unhandled exceptions with: method, path, user_id (from JWT if available), error.
    Return 500 JSON: {"detail": "Internal server error", "type": type(exc).__name__}
    """
```

**Commit:** `feat: add global exception handler and error logging`

---

## PHASE 8 — UX Polish + Edge Cases

---

#### Step 8.1 — Loading Skeletons

`frontend/components/SkeletonMessage.tsx`:
- Renders during initial chat load (before messages arrive)
- Animated shimmer effect using Tailwind `animate-pulse`
- Shows 2-3 fake message bubbles of varying widths

**Commit:** `feat: add skeleton loading states for messages`

---

#### Step 8.2 — Auto-scroll Behavior

In `ChatPanel.tsx`:
- Auto-scroll to bottom when: new message added, processing phase changes
- Smooth scroll: `behavior: 'smooth'`
- If user scrolled up manually: do NOT auto-scroll (detect scroll position delta)

**Commit:** `feat: implement smart auto-scroll in ChatPanel`

---

#### Step 8.3 — Chat Title Auto-Update

After first query in a new chat:
- Backend: call `chat_manager.auto_generate_title(first_query)` and UPDATE chat title
- Frontend: refresh sidebar chat list after receiving response

**Commit:** `feat: auto-generate chat title from first query`

---

#### Step 8.4 — Empty States

Implement empty states for all edge cases:
- No chats: sidebar shows "No chats yet. Click + New Chat to begin."
- New chat, no dataset: main panel shows upload prompt with illustrated icon
- Chat loaded, no messages: shows dataset preview + "Ask your first question…"

**Commit:** `feat: implement empty states for all edge cases`

---

#### Step 8.5 — Input Validation (Frontend)

In `InputBar.tsx`:
- Query empty → Send button disabled
- Query > 1000 chars → character counter shows in red; Send disabled
- While loading → textarea disabled, send button shows spinner

**Commit:** `feat: add input validation and character counter to InputBar`

---

#### Step 8.6 — Rate Limit Feedback

If backend returns 429 (LLM rate limit):
- Show: "You've hit the rate limit. Please wait a moment before trying again."
- Auto-dismiss after 5 seconds

**Commit:** `feat: handle LLM rate limit with user-friendly feedback`

---

#### Step 8.7 — Responsive Layout

Ensure layout works at 768px+ (tablet minimum):
- At < 768px: sidebar hidden by default, hamburger menu button in top-left
- Sidebar toggles as overlay on mobile

**Commit:** `feat: add responsive layout for mobile and tablet`

---

## PHASE 9 — Integration Testing + Stability

---

#### Step 9.1 — Backend: Health Check and Readiness

Add `/health` endpoint that checks:
- Supabase connection: `supabase.table('users').select('count')` 
- ChromaDB: list collections
- Upload dir writable

Returns: `{status: "ok" | "degraded", checks: {supabase, chroma, filesystem}}`

**Commit:** `feat: implement health check endpoint with dependency status`

---

#### Step 9.2 — Backend: Input Sanitization

Ensure all user inputs are sanitized:
- `query`: strip leading/trailing whitespace; reject if empty after strip
- `chat_id`: validate UUID format before Supabase query
- Uploaded filename: sanitize for filesystem safety (`secure_filename()`)

**Commit:** `feat: add input sanitization for all API endpoints`

---

#### Step 9.3 — ChromaDB Collection Lifecycle

Handle edge cases for ChromaDB:
- If collection already exists on re-start → `get_or_create_collection` handles it
- If collection not found during query → return 400 "Dataset indexing failed. Please re-upload."
- Protect against collection name collisions (use dataset UUID as collection name)

**Commit:** `feat: harden ChromaDB collection lifecycle management`

---

#### Step 9.4 — Dataset File Lifecycle

- If CSV file missing on disk when query sent → 404 "Dataset file no longer available. Create a new chat."
- Add `data/uploads/` and `data/chroma/` to `.gitignore`
- Add `data/.gitkeep` to preserve directory structure in git

**Commit:** `feat: handle missing dataset file gracefully`

---

#### Step 9.5 — End-to-End Test Scenarios (Manual)

Document in `backend/tests/manual_test_cases.md`:

Test 1: Full happy path
- Upload Titanic dataset CSV
- Ask: "What is the average age of passengers?"
- Expected: scalar result, correct Pandas code, reasoning shown

Test 2: Aggregation with groupby
- Ask: "What is the survival rate by passenger class?"
- Expected: DataFrame result with groupby aggregation

Test 3: Invalid query
- Ask: "What is the weather in London?"
- Expected: graceful rejection with explanation

Test 4: Past chat continuation
- Close browser, reopen, navigate to past chat
- Ask follow-up question
- Expected: context preserved, correct answer

Test 5: Rate limit simulation
- Make 5 rapid queries
- Expected: 429 handled gracefully

**Commit:** `docs: add manual end-to-end test cases`

---

## PHASE 10 — Final Cleanup

---

#### Step 10.1 — README with Setup Instructions

`README.md` — complete setup guide:
```markdown
# Lumiq — AI-Powered Conversational Data Analysis

## Prerequisites
- Python 3.11+
- Node.js 18+
- Supabase account (free tier)
- Groq API key (free tier: https://console.groq.com)

## Setup

### 1. Supabase
- Create new project at https://supabase.com
- Run `backend/db/migrations/001_initial_schema.sql` in SQL editor
- Copy Project URL and anon key

### 2. Backend
cd backend
pip install -r requirements.txt
cp ../.env.example .env
# Fill in SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, LLM_API_KEY
uvicorn main:app --reload --port 8000

### 3. Frontend
cd frontend
npm install
cp ../.env.example .env.local
# Fill in NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, NEXT_PUBLIC_API_BASE_URL
npm run dev

## Access
Open http://localhost:3000
```

**Commit:** `docs: complete README with setup instructions`

---

#### Step 10.2 — Environment Variable Validation

`backend/config.py` — add startup validation:
```python
# On startup, validate all required env vars are set
# If any missing, raise RuntimeError with clear message: "Missing required env var: {name}"
```

**Commit:** `feat: add startup environment variable validation`

---

#### Step 10.3 — Final Commit

Verify:
- All TypeScript `any` types documented with comments
- No `console.log` debug statements in production code
- No hardcoded API keys or secrets anywhere
- `.env` in `.gitignore`
- All routes protected by auth middleware

**Commit:** `chore: final cleanup, remove debug logs, verify security`

---

## Commit Count Summary

| Phase | Min Commits |
|---|---|
| Phase 0: Setup | 7 |
| Phase 1: Auth | 5 |
| Phase 2: Chat UI Shell | 10 |
| Phase 3: Dataset Upload | 6 |
| Phase 4: Chat System | 5 |
| Phase 5: LLM + Code Gen | 8 |
| Phase 6: Frontend Query | 4 |
| Phase 7: Logging | 2 |
| Phase 8: UX Polish | 7 |
| Phase 9: Stability | 5 |
| Phase 10: Cleanup | 3 |
| **Total** | **72** |

---

## Critical Constraints Checklist

Before marking any phase complete, verify:

- [ ] RAG is called on EVERY `/chat` request — no exceptions
- [ ] All code execution goes through `ExecutionEngine` with restricted globals
- [ ] No LLM response is returned without code execution (no fabricated results)
- [ ] Chat isolation enforced: ChromaDB collection ID = dataset UUID (unique per chat)
- [ ] All API endpoints check `user_id` from JWT, not from request body
- [ ] Supabase RLS policies are active (never bypass with service key for user data)
- [ ] UI shows all 6 processing phases for every query
- [ ] ChatGPT layout: sidebar + main panel + bottom input — do not deviate
- [ ] All 6 frontend processing phases are animated
- [ ] Error responses never return Python tracebacks to the client (log server-side only)
- [ ] Max 2 retries before returning rejection response
- [ ] Dataset file is stored server-side; not re-uploaded on every query
