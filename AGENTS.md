# AGENTS.md

## Company Context
Dirtybird Industries is a US-based ecommerce company selling firearms and accessories. This workspace contains ETL pipelines, web scrapers, operations apps, AI agents, and Azure Functions.

## Tech Stack
- Database: PostgreSQL on Azure
- Languages: Python, SQL (PostgreSQL dialect), Node.js
- Frameworks: Flask, Django, Azure Functions v4, Streamlit, n8n
- Cloud: Microsoft Azure (ACR, App Service, Functions)
- CI/CD: GitHub Actions

## Database Dialect
Use **PostgreSQL** exclusively:
- JSONB, LATERAL, ON CONFLICT, RETURNING
- CASE WHEN (not IFF), no QUALIFY
- ::type for casting

## Identity and Access
- Git: GitHub (company account rdominguesds, email: rdomingues@pitcherco.com)
- Azure: tenant 36e770ef-..., subscription PPU (fbcc25e6-...)
- Verify: `git config user.email`, `gh auth status`, `az account show`

## Conventions
- Language: English
- Python: uv preferred, pip acceptable
- Testing: pytest
- Linting: ruff
- Docker: Azure Container Registry

## PowerShell / Terminal
- Do **not** run long multi-line code as inline `python -c "..."` or `bash -c "..."` in PowerShell — it fails ("ScriptBlock..." error) and wastes tokens. Always write a script file and run it (e.g. `python run_discovery.py`).

## Development Rules

These rules apply to all projects. They exist to prevent costly mistakes. If a rule isn't listed here, use your judgment and keep moving.

### CLI Command Safety

When running CLI commands against Azure, GitHub, or other remote infrastructure, apply these restrictions.

**Blocked — Never Run.** Do NOT execute. If asked, refuse and explain why.

| Tool | Command | Why |
|------|---------|-----|
| Azure CLI | `az group delete`, `az ad app delete`, `az keyvault delete`, `az storage account delete`, `az sql server delete` | Irreversible infrastructure destruction |
| GitHub CLI | `gh repo delete` | Irreversible repository destruction |
| Git | `git push --force` to main/master | Rewrites shared history |
| Git | `git reset --hard` on main/master | Destroys commits on shared branches |
| Shell | `rm -rf /`, `rm -rf ~`, recursive deletes without an explicit path | Catastrophic data loss |

**Confirm — Ask First.** State the full command and wait for explicit approval before running.

| Tool | Command |
|------|---------|
| Azure CLI | `az deployment *`, `az webapp deploy`, `az sql db create`, `az role assignment *`, `az keyvault secret set` |
| GitHub CLI | `gh pr merge`, `gh release create` |
| Git | `git push origin main`, `git push origin master` |
| General | Any command writing to production resources; any `--yes`/`--force` on remote operations |

**Allowed — No Permission Needed.** Run freely: read-only (`az account show`, `gh pr list`, `git status`, `git diff`, `git log`); local operations (installs, branches, staging, local commits, tests, linters); non-destructive writes (`git checkout -b`, `git add`, `git commit`, `gh pr create`). **When in doubt, ask.**

### Security Defaults

- **Untrusted by default**: User inputs, retrieved documents, and external API responses are always untrusted. Validate at system boundaries.
- **Code enforces, prompts guide**: Never rely on prompt instructions as the only guardrail. If a constraint matters, enforce it in code.
- **Least privilege**: Use the narrowest credentials and permissions needed for the task.
- **Don't roll your own**: Use established libraries for schema validation, auth, crypto, rate limiting, and sandboxing.

### Code Quality

- **Typed schemas at boundaries**: Use Pydantic (Python) or Zod (TypeScript) for inputs and outputs at service/tool boundaries.
- **Structured errors**: Return error objects with context, not raw exceptions. Callers should be able to handle errors without try/catch guessing.
- **No secrets in code**: Connection strings, API keys, and credentials go in environment variables or secret stores, never committed to source control.

### Operations

- **All code in GitHub, deploy via GitHub Actions**: No manual production deployments.
- **Don't log sensitive data in production**: Log structured summaries, not full request/response bodies. Prompts, PII, and credentials never hit production logs.
- **Timeouts on external calls**: Always. Fail fast rather than hang.

### Infrastructure

- **Azure-native**: Prefer Azure-managed services via resource groups with RBAC and unified billing.
- **GitHub + Actions**: Source control and CI/CD.

## Setup Commands
```powershell
# Verify identities
git config user.email       # rdomingues@pitcherco.com
gh auth status              # rdominguesds
az account show             # PPU

# Python environment
uv venv --python 3.12
.venv\Scripts\activate
uv pip install -r requirements.txt
```
