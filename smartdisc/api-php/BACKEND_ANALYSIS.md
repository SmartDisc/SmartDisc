# SmartDisc Backend – Requirements Analysis & Review

This document checks the PHP backend in `api-php/` against the diploma thesis backend goals and notes correctness, completeness, and robustness.

---

## 1. REST API Development

| Requirement | Status | Notes |
|-------------|--------|--------|
| REST API receives sensor data from SmartDisc | ✅ Met | `POST /api/wurfe` accepts `scheibe_id`, `rotation`, `hoehe`, `acceleration_x/y/z`, `acceleration_max`, `player_id`. |
| API accepts data from ground station | ✅ Met | Same endpoint; no distinction between app and ground station. |
| Validate incoming data before storing | ✅ Met | Required: `scheibe_id`; at least one of `rotation`, `hoehe`, `acceleration_max`. Type normalization (float). Duplicate detection (5s window, 1% tolerance). |
| Endpoints for retrieving throw data | ✅ Met | `GET /api/wurfe` (list with filters), `GET /api/wurfe/:id` (single). |
| REST principles (clear endpoints, HTTP methods, status codes) | ✅ Met | Resource names (`/api/wurfe`, `/api/scheiben`, `/api/stats/summary`, etc.), GET/POST/DELETE used appropriately. Status codes: 200, 201, 400, 401, 403, 404, 405, 409, 500. |

**Verdict:** REST API goals are fulfilled.

---

## 2. Database Storage

| Requirement | Status | Notes |
|-------------|--------|--------|
| All sensor data from throws stored in structured DB | ✅ Met | Table `wurfe`: id, scheibe_id, player_id, rotation, hoehe, acceleration_x/y/z, acceleration_max, erstellt_am, geaendert_am, version, geloescht. |
| Persistent and retrievable | ✅ Met | SQLite in `api-php/data/smartdisc.db`. |
| Supports throw id, user id, timestamp, rotation speed, acceleration, height, metadata | ✅ Met | `id`, `player_id`, `erstellt_am`, `rotation`, `acceleration_*`, `hoehe`; version/soft-delete as metadata. |
| Efficient querying and filtering | ✅ Met | Indexes on `scheibe_id`, `erstellt_am`, `player_id`, `geloescht`. Prepared statements throughout. |

**Verdict:** Database storage goals are fulfilled.

---

## 3. Filtering and Analysis Functions

| Requirement | Status | Notes |
|-------------|--------|--------|
| Filter by date | ✅ Met | `GET /api/wurfe?from=...&to=...` (and in export). |
| Filter by speed (rotation) | ⚠️ Partial | Export has `minRot`/`maxRot`; **list endpoint did not** (fixed: added `minRotation`, `maxRotation` to GET `/api/wurfe`). |
| Filter by distance/height | ⚠️ Partial | Export has `minHeight`/`maxHeight`; **list endpoint did not** (fixed: added `minHeight`, `maxHeight` to GET `/api/wurfe`). |
| Filter by user/player | ✅ Met | `GET /api/wurfe?player_id=...`. |
| Endpoints returning analyzed/aggregated data | ✅ Met | `GET /api/stats/summary`: count, rotationMax/Avg, heightMax/Avg, accelerationMax/Avg. |

**Verdict:** Filtering and analysis are now fully covered after adding list filters.

---

## 4. Error and Status Handling

| Requirement | Status | Notes |
|-------------|--------|--------|
| Invalid data | ✅ Met | 400 + `VALIDATION_ERROR` (e.g. missing scheibe_id, no measurement values). |
| Missing fields | ✅ Met | Same validation; clear messages. |
| Server errors | ✅ Met | 500 + `INSERT_FAILED` / `REGISTER_FAILED` etc. and exception message. |
| Connection/DB errors | ✅ Met | `db.php`: 500 + `DB_CONNECT_ERROR` on PDO failure. |
| Clear error messages and HTTP status codes | ✅ Met | Consistent `{ "error": { "code": "...", "message": "..." } }` and appropriate status. |

**Gaps:**

- **Malformed JSON body:** `get_json_input()` uses `json_decode(..., true) ?? []`. Invalid JSON yields `[]` and no 400. Recommendation: detect invalid JSON and return 400 "Invalid JSON" (see implementation note below).
- **Uncaught exceptions:** No global `set_exception_handler`. Unexpected errors show PHP default behavior. Recommendation: add a global handler that returns 500 JSON and logs.

**Verdict:** Error handling is good; small improvements possible for invalid JSON and global exceptions.

---

## 5. Data Visualization Support

| Requirement | Status | Notes |
|-------------|--------|--------|
| Endpoints for statistics and throw history | ✅ Met | `GET /api/stats/summary`, `GET /api/wurfe` (with limit and filters). |
| Structured JSON for charts/statistics | ✅ Met | Summary returns `count`, `rotationMax`/`rotationAvg`, `heightMax`/`heightAvg`, `accelerationMax`/`accelerationAvg`. List returns `items` array with per-throw fields. |

**Verdict:** Data visualization support is in place.

---

## 6. Data Export (Optional)

| Requirement | Status | Notes |
|-------------|--------|--------|
| Export stored data (e.g. CSV or PDF) | ⚠️ Partial | **CSV:** `GET /api/exports/throws?format=csv` with filters; auth required. **PDF:** Not implemented (TCPDF is in vendor but not used in routes). Legacy `GET /api/export.csv` exists **without auth** and exposes all throws. |

**Recommendations:**

- Secure or remove legacy `/api/export.csv` (e.g. require auth or deprecate).
- Optional: add PDF export using TCPDF for thesis completeness.

**Verdict:** CSV export is implemented and suitable; PDF and legacy route need attention.

---

## 7. Ranking / Highscore System (Optional)

| Requirement | Status | Notes |
|-------------|--------|--------|
| Backend can calculate rankings from throw performance | ✅ Met | Table `highscores` (user_id, best_rotation, best_hoehe, best_acceleration_max); updated on each throw when `player_id` is set. |
| Expose rankings via API | ⚠️ Was missing | No GET endpoint for highscores/rankings. **Fixed:** added `GET /api/highscores` (and optional `GET /api/highscores/me` for current user). |

**Verdict:** Calculation was there; API exposure is now added.

---

## 8. System Stability

| Requirement | Status | Notes |
|-------------|--------|--------|
| Stable under frequent sensor data | ✅ Good | Prepared statements, duplicate detection to avoid repeated inserts, SQLite suitable for moderate load. |
| Structured, readable, maintainable code | ✅ Good | Separate route files (auth, wurfe, stats, export, scheiben, admin, assignments, revisionen, misc), shared lib (http, auth, audit), single entry point. |

**Verdict:** Architecture and stability are adequate for a diploma project.

---

## Architecture Summary

- **Entry:** `index.php` (and `router.php` for built-in server). CORS and path/method parsed; route files included in order; 404 fallback.
- **DB:** `db.php` creates SQLite PDO and tables/indexes; failures return 500 JSON.
- **Routes:** Path + method matching; use `$pdo`, `get_json_input()`, `json_response()`, auth helpers. Role-based access (player vs trainer) where needed.
- **Security:** Bearer token auth; players restricted to their assigned discs/throws; trainers can manage assignments and see overview.

---

## Potential Bugs and Weaknesses (and Fixes)

1. **Legacy export without auth** – `GET /api/export.csv` returns all throws. **Recommendation:** Require auth or remove/deprecate.
2. **List throws missing speed/height filters** – **Fixed** in `routes/wurfe.php`: added `minRotation`, `maxRotation`, `minHeight`, `maxHeight` query params.
3. **No ranking endpoint** – **Fixed:** new route file or block for `GET /api/highscores` (and optionally `GET /api/highscores/me`).
4. **Invalid JSON on POST** – `get_json_input()` returns `[]` for malformed JSON. **Recommendation:** In `lib/http.php`, check `json_last_error()` when content-type is JSON and return 400 for invalid body.
5. **scheibe_id type** – DB uses TEXT; hardware may send numeric. Code casts to int; SQLite accepts but string is more consistent. **Recommendation:** Store as string for consistency with `scheiben.id`.

---

## Diploma Thesis Suitability

- The backend implements the required REST API, persistence, validation, filtering, analysis, visualization support, and optional CSV export and highscore calculation.
- With the added list filters and highscores endpoint (and optional invalid-JSON and legacy-export fixes), it meets the stated goals and is technically sound for a diploma thesis. Documentation of design choices (e.g. SQLite, role-based access, duplicate detection) will strengthen the written part.

---

## File Reference

- Entry: `api-php/index.php`, `api-php/router.php`
- DB: `api-php/db.php`
- HTTP/auth/audit: `api-php/lib/http.php`, `api-php/lib/auth.php`, `api-php/lib/audit.php`
- Routes: `api-php/routes/*.php` (auth, wurfe, stats, export, scheiben, admin, assignments, revisionen, misc; highscores added as described above)
