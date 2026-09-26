interface Env {
  DB: D1Database;
  ASSETS: Fetcher;
}

type LocationRow = {
  id: string;
  slug: string;
  display_name: string;
  region: string | null;
  state: "PREPARING" | "LIVE" | "PAUSED" | "RETIRED";
};

type ProductRow = {
  product_key: string;
  display_name: string;
  short_description: string;
  icon_ref: string;
  entry_url: string;
  location_product_state: "LIVE" | "PAUSED";
  availability_message: string | null;
};

const JSON_HEADERS: HeadersInit = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "public, max-age=30, s-maxage=120, stale-while-revalidate=300",
  "x-content-type-options": "nosniff",
};

const NO_STORE_JSON_HEADERS: HeadersInit = {
  ...JSON_HEADERS,
  "cache-control": "no-store",
};

function json(data: unknown, status = 200, headers: HeadersInit = JSON_HEADERS) {
  return new Response(JSON.stringify(data), { status, headers });
}

function normalizeLocationSlug(value: string | null) {
  const slug = (value ?? "").trim().toLowerCase();
  if (!/^[a-z0-9][a-z0-9-]{0,62}$/.test(slug)) return null;
  return slug;
}

async function listLocations(env: Env) {
  const query = env.DB.prepare(
    `SELECT id, slug, display_name, region, state
     FROM locations
     WHERE state = 'LIVE'
     ORDER BY display_order ASC, display_name ASC`
  );
  const result = await query.all<LocationRow>();
  return result.results ?? [];
}

async function getLocation(env: Env, slug: string) {
  return env.DB.prepare(
    `SELECT id, slug, display_name, region, state
     FROM locations
     WHERE slug = ?
     LIMIT 1`
  ).bind(slug).first<LocationRow>();
}

async function getLocationProducts(env: Env, locationId: string) {
  const result = await env.DB.prepare(
    `SELECT
       p.product_key,
       COALESCE(lp.local_display_name, p.display_name) AS display_name,
       COALESCE(lp.local_short_description, p.short_description) AS short_description,
       p.icon_ref,
       p.entry_url,
       lp.state AS location_product_state,
       lp.availability_message
     FROM location_products lp
     INNER JOIN products p ON p.id = lp.product_id
     WHERE lp.location_id = ?
       AND p.state = 'ACTIVE'
       AND lp.state IN ('LIVE', 'PAUSED')
     ORDER BY COALESCE(lp.display_order, p.display_order) ASC, display_name ASC`
  ).bind(locationId).all<ProductRow>();

  return result.results ?? [];
}

function apiNotFound() {
  return json(
    { error: { code: "API_NOT_FOUND", message: "That Raahi API route does not exist." } },
    404,
    NO_STORE_JSON_HEADERS
  );
}

async function handleApi(request: Request, env: Env) {
  const url = new URL(request.url);

  if (request.method !== "GET") {
    return json(
      { error: { code: "METHOD_NOT_ALLOWED", message: "This endpoint is read-only." } },
      405,
      { ...NO_STORE_JSON_HEADERS, allow: "GET" }
    );
  }

  if (url.pathname === "/api/v1/health") {
    let schemaVersion = "unknown";
    try {
      const row = await env.DB.prepare(
        "SELECT value FROM schema_meta WHERE key = 'schema_version' LIMIT 1"
      ).first<{ value: string }>();
      if (row?.value) schemaVersion = row.value;
    } catch {
      // Health should still distinguish a running Worker from schema readiness.
    }

    return json(
      { ok: true, service: "myraahi-shell", schema_version: schemaVersion },
      200,
      NO_STORE_JSON_HEADERS
    );
  }

  if (url.pathname === "/api/v1/locations") {
    return json({ locations: await listLocations(env) });
  }

  if (url.pathname === "/api/v1/catalog") {
    const slug = normalizeLocationSlug(url.searchParams.get("location"));
    if (!slug) {
      return json(
        { error: { code: "LOCATION_REQUIRED", message: "Choose a Raahi location." } },
        400,
        NO_STORE_JSON_HEADERS
      );
    }

    const location = await getLocation(env, slug);
    if (!location) {
      return json(
        { error: { code: "LOCATION_NOT_FOUND", message: "That Raahi location is not available." } },
        404,
        NO_STORE_JSON_HEADERS
      );
    }

    if (location.state !== "LIVE") {
      return json(
        {
          error: {
            code: "LOCATION_NOT_SELECTABLE",
            message:
              location.state === "PAUSED"
                ? `Raahi is temporarily unavailable in ${location.display_name}.`
                : `Raahi is not currently available in ${location.display_name}.`,
          },
          location: {
            slug: location.slug,
            display_name: location.display_name,
            state: location.state,
          },
        },
        409,
        NO_STORE_JSON_HEADERS
      );
    }

    const products = await getLocationProducts(env, location.id);
    return json({
      location: {
        slug: location.slug,
        display_name: location.display_name,
        region: location.region,
        state: location.state,
      },
      products: products.map((product) => ({
        key: product.product_key,
        display_name: product.display_name,
        short_description: product.short_description,
        icon_ref: product.icon_ref,
        state: product.location_product_state,
        entry_url: product.entry_url,
        availability_message: product.availability_message,
      })),
    });
  }

  return apiNotFound();
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/api/")) {
      try {
        return await handleApi(request, env);
      } catch (error) {
        console.error("myraahi-shell api error", error);
        return json(
          {
            error: {
              code: "SERVICE_UNAVAILABLE",
              message: "Raahi could not load this right now. Please try again.",
            },
          },
          503,
          NO_STORE_JSON_HEADERS
        );
      }
    }

    const response = await env.ASSETS.fetch(request);
    const headers = new Headers(response.headers);
    headers.set("x-content-type-options", "nosniff");
    headers.set("referrer-policy", "strict-origin-when-cross-origin");
    headers.set("x-frame-options", "DENY");
    headers.set(
      "permissions-policy",
      "camera=(), microphone=(), geolocation=()"
    );

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  },
} satisfies ExportedHandler<Env>;
