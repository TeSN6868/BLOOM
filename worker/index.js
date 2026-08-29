export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/api/health") {
      return json({
        ok: true,
        service: "BLOOM API",
        time: Date.now()
      });
    }

    if (request.method === "GET" && url.pathname === "/api/posts") {
      const userId = url.searchParams.get("user_id");

      if (!userId) {
        return json({ ok: false, error: "user_id_required" }, 400);
      }

      const result = await env.DB.prepare(`
        SELECT
          id,
          user_id,
          text,
          media_url,
          media_type,
          location,
          activity,
          created_at,
          updated_at
        FROM posts
        WHERE user_id = ?
        ORDER BY created_at DESC
      `).bind(userId).all();

      return json({
        ok: true,
        posts: result.results ?? []
      });
    }

    if (request.method === "POST" && url.pathname === "/api/posts") {
      const body = await request.json();

      const userId = String(body.user_id ?? "").trim();
      const text = String(body.text ?? "");
      const mediaUrl = String(body.media_url ?? "");
      const mediaType = String(body.media_type ?? "");
      const location = String(body.location ?? "");
      const activity = String(body.activity ?? "");

      if (!userId) {
        return json({ ok: false, error: "user_id_required" }, 400);
      }

      const id = crypto.randomUUID();
      const now = Date.now();

      await env.DB.prepare(`
        INSERT INTO posts (
          id,
          user_id,
          text,
          media_url,
          media_type,
          location,
          activity,
          created_at,
          updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).bind(
        id,
        userId,
        text,
        mediaUrl,
        mediaType,
        location,
        activity,
        now,
        now
      ).run();

      return json({
        ok: true,
        post: {
          id,
          user_id: userId,
          text,
          media_url: mediaUrl,
          media_type: mediaType,
          location,
          activity,
          created_at: now,
          updated_at: now
        }
      }, 201);
    }

    if (request.method === "PUT" && url.pathname.startsWith("/api/posts/")) {
      const id = url.pathname.split("/").pop();

      if (!id) {
        return json({ ok: false, error: "id_required" }, 400);
      }

      const body = await request.json();

      const text = String(body.text ?? "");
      const location = String(body.location ?? "");
      const activity = String(body.activity ?? "");
      const mediaUrl = String(body.media_url ?? "");
      const mediaType = String(body.media_type ?? "");
      const now = Date.now();

      await env.DB.prepare(`
        UPDATE posts
        SET
          text = ?,
          location = ?,
          activity = ?,
          media_url = ?,
          media_type = ?,
          updated_at = ?
        WHERE id = ?
      `).bind(
        text,
        location,
        activity,
        mediaUrl,
        mediaType,
        now,
        id
      ).run();

      const result = await env.DB.prepare(`
        SELECT
          id,
          user_id,
          text,
          media_url,
          media_type,
          location,
          activity,
          created_at,
          updated_at
        FROM posts
        WHERE id = ?
        LIMIT 1
      `).bind(id).first();

      if (!result) {
        return json({ ok: false, error: "post_not_found" }, 404);
      }

      return json({
        ok: true,
        post: result
      });
    }

    if (request.method === "DELETE" && url.pathname.startsWith("/api/posts/")) {
      const id = url.pathname.split("/").pop();

      if (!id) {
        return json({ ok: false, error: "id_required" }, 400);
      }

      await env.DB.prepare(`
        DELETE FROM posts WHERE id = ?
      `).bind(id).run();

      return json({
        ok: true,
        deleted: id
      });
    }

    if (
      request.method === "GET" &&
      url.pathname === "/api/notifications"
    ) {
      const userId = url.searchParams.get("user_id");

      if (!userId) {
        return json({ ok: false, error: "user_id_required" }, 400);
      }

      const result = await env.DB.prepare(`
        SELECT
          id,
          type,
          title,
          body,
          post_id,
          created_at,
          is_read
        FROM notifications
        WHERE user_id = ?
        ORDER BY created_at DESC
      `).bind(userId).all();

      return json({
        ok: true,
        notifications: result.results ?? []
      });
    }


    // =========================
    // BLOOM ACCOUNT
    // =========================

    if (request.method === "POST" && url.pathname === "/api/register") {
      const body = await request.json();

      const username = String(body.username ?? "").trim().toLowerCase();
      const pin = String(body.pin ?? "").trim();
      const name = String(body.name ?? username).trim();

      if (!username || !pin) {
        return json({
          ok: false,
          error: "username_and_pin_required"
        }, 400);
      }

      if (!/^[a-z0-9_.]{3,30}$/.test(username)) {
        return json({
          ok: false,
          error: "invalid_username"
        }, 400);
      }

      if (!/^\d{6}$/.test(pin)) {
        return json({
          ok: false,
          error: "pin_must_be_6_digits"
        }, 400);
      }

      const existing = await env.DB.prepare(`
        SELECT id
        FROM users
        WHERE username = ?
        LIMIT 1
      `).bind(username).first();

      if (existing) {
        return json({
          ok: false,
          error: "username_already_exists"
        }, 409);
      }

      const id = crypto.randomUUID();
      const pinHash = await hashPin(pin);
      const now = Date.now();

      await env.DB.prepare(`
        INSERT INTO users (
          id,
          name,
          username,
          bio,
          photo_url,
          background_url,
          pin_hash,
          created_at
        )
        VALUES (?, ?, ?, '', '', '', ?, ?)
      `).bind(
        id,
        name || username,
        username,
        pinHash,
        now
      ).run();

      return json({
        ok: true,
        user: {
          id,
          name: name || username,
          username,
          bio: "",
          photo_url: "",
          background_url: "",
          created_at: now
        }
      }, 201);
    }

    if (request.method === "POST" && url.pathname === "/api/login") {
      const body = await request.json();

      const username = String(body.username ?? "").trim().toLowerCase();
      const pin = String(body.pin ?? "").trim();

      if (!username || !pin) {
        return json({
          ok: false,
          error: "username_and_pin_required"
        }, 400);
      }

      const user = await env.DB.prepare(`
        SELECT
          id,
          name,
          username,
          bio,
          photo_url,
          background_url,
          pin_hash,
          role,
          verified_badge,
          created_at
        FROM users
        WHERE username = ?
        LIMIT 1
      `).bind(username).first();

      if (!user) {
        return json({
          ok: false,
          error: "invalid_credentials"
        }, 401);
      }

      const valid = await verifyPin(pin, String(user.pin_hash ?? ""));

      if (!valid) {
        return json({
          ok: false,
          error: "invalid_credentials"
        }, 401);
      }

      return json({
        ok: true,
        user: {
          id: user.id,
          name: user.name,
          username: user.username,
          bio: user.bio ?? "",
          photo_url: user.photo_url ?? "",
          background_url: user.background_url ?? "",
          role: user.role ?? "user",
          verified_badge: user.verified_badge ?? "",
          created_at: user.created_at
        }
      });
    }

    // =========================
    // BLOOM ACCOUNT / PROFILE
    // =========================

    // =========================
    // BLOOM USER SEARCH
    // =========================

    if (request.method === "GET" && url.pathname === "/api/users/search") {
      const q = String(
        url.searchParams.get("q") ?? ""
      ).trim().toLowerCase();

      if (!q) {
        return json({
          ok: false,
          error: "query_required"
        }, 400);
      }

      if (q.length < 2) {
        return json({
          ok: false,
          error: "query_too_short"
        }, 400);
      }

      const result = await env.DB.prepare(`
        SELECT
          id,
          name,
          username,
          bio,
          photo_url,
          verified_badge,
          created_at
        FROM users
        WHERE
          LOWER(username) LIKE ?
          OR LOWER(name) LIKE ?
        ORDER BY
          CASE
            WHEN LOWER(username) = ? THEN 0
            WHEN LOWER(username) LIKE ? THEN 1
            ELSE 2
          END,
          created_at DESC
        LIMIT 20
      `).bind(
        `%${q}%`,
        `%${q}%`,
        q,
        `${q}%`
      ).all();

      return json({
        ok: true,
        users: result.results ?? []
      });
    }

    if (request.method === "GET" && url.pathname === "/api/profile") {
      const userId = url.searchParams.get("user_id");

      if (!userId) {
        return json({ ok: false, error: "user_id_required" }, 400);
      }

      const user = await env.DB.prepare(`
        SELECT
          id,
          name,
          username,
          bio,
          photo_url,
          background_url,
          verified_badge,
          created_at
        FROM users
        WHERE id = ?
        LIMIT 1
      `).bind(userId).first();

      if (!user) {
        return json({
          ok: false,
          error: "user_not_found"
        }, 404);
      }

      return json({
        ok: true,
        user
      });
    }

    if (request.method === "PUT" && url.pathname === "/api/profile") {
      const body = await request.json();

      const userId = String(body.user_id ?? "").trim();

      if (!userId) {
        return json({ ok: false, error: "user_id_required" }, 400);
      }

      const existingUser = await env.DB.prepare(`
        SELECT id
        FROM users
        WHERE id = ?
        LIMIT 1
      `).bind(userId).first();

      if (!existingUser) {
        return json({
          ok: false,
          error: "user_not_found"
        }, 404);
      }

      const name = String(body.name ?? "").trim();
      const username = String(body.username ?? "").trim();
      const bio = String(body.bio ?? "");
      const photoUrl = String(body.photo_url ?? "");
      const backgroundUrl = String(body.background_url ?? "");

      if (!username) {
        return json({
          ok: false,
          error: "username_required"
        }, 400);
      }

      try {
        await env.DB.prepare(`
          UPDATE users
          SET
            name = ?,
            username = ?,
            bio = ?,
            photo_url = ?,
            background_url = ?
          WHERE id = ?
        `).bind(
          name,
          username,
          bio,
          photoUrl,
          backgroundUrl,
          userId
        ).run();
      } catch (e) {
        return json({
          ok: false,
          error: "profile_update_failed"
        }, 409);
      }

      const user = await env.DB.prepare(`
        SELECT
          id,
          name,
          username,
          bio,
          photo_url,
          background_url,
          created_at
        FROM users
        WHERE id = ?
        LIMIT 1
      `).bind(userId).first();

      if (!user) {
        return json({
          ok: false,
          error: "user_not_found"
        }, 404);
      }

      return json({
        ok: true,
        user
      });
    }


    // =========================
    // BLOOM CONNECTIONS
    // =========================

    if (
      request.method === "GET" &&
      url.pathname === "/api/connections"
    ) {
      const userId = String(
        url.searchParams.get("user_id") ?? ""
      ).trim();

      if (!userId) {
        return json({
          ok: false,
          error: "user_id_required"
        }, 400);
      }

      const result = await env.DB.prepare(`
        SELECT
          c.id,
          c.from_user_id,
          c.to_user_id,
          c.kind,
          c.created_at,
          CASE
            WHEN c.from_user_id = ? THEN c.to_user_id
            ELSE c.from_user_id
          END AS other_user_id
        FROM bloom_connections c
        WHERE
          c.from_user_id = ?
          OR c.to_user_id = ?
        ORDER BY c.created_at DESC
      `).bind(
        userId,
        userId,
        userId
      ).all();

      return json({
        ok: true,
        connections: result.results ?? []
      });
    }

    if (
      request.method === "POST" &&
      url.pathname === "/api/connections"
    ) {
      const body = await request.json();

      const userId = String(body.user_id ?? "").trim();
      const targetUserId = String(
        body.target_user_id ?? ""
      ).trim();
      const kind = String(body.kind ?? "")
        .trim()
        .toLowerCase();

      if (!userId || !targetUserId || !kind) {
        return json({
          ok: false,
          error: "connection_fields_required"
        }, 400);
      }

      if (userId === targetUserId) {
        return json({
          ok: false,
          error: "cannot_connect_self"
        }, 400);
      }

      if (!["root", "sprout", "branch"].includes(kind)) {
        return json({
          ok: false,
          error: "invalid_connection_kind"
        }, 400);
      }

      const users = await env.DB.prepare(`
        SELECT id
        FROM users
        WHERE id IN (?, ?)
      `).bind(
        userId,
        targetUserId
      ).all();

      if ((users.results ?? []).length != 2) {
        return json({
          ok: false,
          error: "user_not_found"
        }, 404);
      }

      const existing = await env.DB.prepare(`
        SELECT
          id,
          from_user_id,
          to_user_id,
          kind,
          created_at
        FROM bloom_connections
        WHERE
          (
            (from_user_id = ? AND to_user_id = ?)
            OR
            (from_user_id = ? AND to_user_id = ?)
          )
          AND kind = ?
        LIMIT 1
      `).bind(
        userId,
        targetUserId,
        targetUserId,
        userId,
        kind
      ).first();

      if (existing) {
        return json({
          ok: true,
          already_exists: true,
          connection: existing
        });
      }

      const id = crypto.randomUUID();
      const now = Date.now();

      await env.DB.prepare(`
        INSERT INTO bloom_connections (
          id,
          from_user_id,
          to_user_id,
          kind,
          created_at
        )
        VALUES (?, ?, ?, ?, ?)
      `).bind(
        id,
        userId,
        targetUserId,
        kind,
        now
      ).run();

      return json({
        ok: true,
        already_exists: false,
        connection: {
          id,
          from_user_id: userId,
          to_user_id: targetUserId,
          kind,
          created_at: now
        }
      });
    }

    if (
      request.method === "DELETE" &&
      url.pathname === "/api/connections"
    ) {
      const userId = String(
        url.searchParams.get("user_id") ?? ""
      ).trim();

      const targetUserId = String(
        url.searchParams.get("target_user_id") ?? ""
      ).trim();

      const kind = String(
        url.searchParams.get("kind") ?? ""
      ).trim().toLowerCase();

      if (!userId || !targetUserId || !kind) {
        return json({
          ok: false,
          error: "connection_fields_required"
        }, 400);
      }

      if (!["root", "sprout", "branch"].includes(kind)) {
        return json({
          ok: false,
          error: "invalid_connection_kind"
        }, 400);
      }

      await env.DB.prepare(`
        DELETE FROM bloom_connections
        WHERE
          from_user_id = ?
          AND to_user_id = ?
          AND kind = ?
      `).bind(
        userId,
        targetUserId,
        kind
      ).run();

      return json({
        ok: true
      });
    }

    // =========================
    // BLOOM PROFILE STATS
    // =========================

    if (request.method === "GET" && url.pathname === "/api/profile/stats") {
      const userId = String(
        url.searchParams.get("user_id") ?? ""
      ).trim();

      if (!userId) {
        return json({ ok: false, error: "user_id_required" }, 400);
      }

      const user = await env.DB.prepare(`
        SELECT id
        FROM users
        WHERE id = ?
        LIMIT 1
      `).bind(userId).first();

      if (!user) {
        return json({
          ok: false,
          error: "user_not_found"
        }, 404);
      }

      const roots = await env.DB.prepare(`
        SELECT COUNT(*) AS count
        FROM bloom_connections
        WHERE to_user_id = ?
          AND kind = 'root'
      `).bind(userId).first();

      const sprouts = await env.DB.prepare(`
        SELECT COUNT(*) AS count
        FROM bloom_connections
        WHERE to_user_id = ?
          AND kind = 'sprout'
      `).bind(userId).first();

      const branches = await env.DB.prepare(`
        SELECT COUNT(*) AS count
        FROM bloom_connections
        WHERE to_user_id = ?
          AND kind = 'branch'
      `).bind(userId).first();

      return json({
        ok: true,
        stats: {
          roots: Number(roots?.count ?? 0),
          sprouts: Number(sprouts?.count ?? 0),
          branches: Number(branches?.count ?? 0)
        }
      });
    }


    // =========================
    // BLOOM STATUS FEED
    // =========================

    if (request.method === "GET" && url.pathname === "/api/status/feed") {
      const userId = String(
        url.searchParams.get("user_id") ?? ""
      ).trim();

      if (!userId) {
        return json({
          ok: false,
          error: "user_id_required"
        }, 400);
      }

      const result = await env.DB.prepare(`
        SELECT
          s.user_id,
          s.text,
          s.updated_at,
          u.name,
          u.username,
          u.photo_url
        FROM bloom_status s
        LEFT JOIN users u
          ON u.id = s.user_id
        WHERE TRIM(s.text) != ''
          AND (
            s.user_id = ?
            OR s.user_id IN (
              SELECT
                CASE
                  WHEN from_user_id = ? THEN to_user_id
                  ELSE from_user_id
                END
              FROM bloom_connections
              WHERE
                (from_user_id = ? OR to_user_id = ?)
                AND kind IN ('root', 'sprout', 'branch')
            )
          )
        ORDER BY s.updated_at DESC
      `).bind(
        userId,
        userId,
        userId,
        userId
      ).all();

      return json({
        ok: true,
        statuses: result.results ?? []
      });
    }


    // =========================
    // BLOOM MY STATUS
    // =========================

    if (request.method === "GET" && url.pathname === "/api/profile/status") {
      const userId = String(
        url.searchParams.get("user_id") ?? ""
      ).trim();

      if (!userId) {
        return json({ ok: false, error: "user_id_required" }, 400);
      }

      const status = await env.DB.prepare(`
        SELECT
          user_id,
          text,
          updated_at
        FROM bloom_status
        WHERE user_id = ?
        LIMIT 1
      `).bind(userId).first();

      return json({
        ok: true,
        status: status ?? {
          user_id: userId,
          text: "",
          updated_at: 0
        }
      });
    }


    if (request.method === "PUT" && url.pathname === "/api/profile/status") {
      const body = await request.json();

      const userId = String(body.user_id ?? "").trim();
      const text = String(body.text ?? "").trim();

      if (!userId) {
        return json({ ok: false, error: "user_id_required" }, 400);
      }

      const user = await env.DB.prepare(`
        SELECT id
        FROM users
        WHERE id = ?
        LIMIT 1
      `).bind(userId).first();

      if (!user) {
        return json({
          ok: false,
          error: "user_not_found"
        }, 404);
      }

      if (text.length > 500) {
        return json({
          ok: false,
          error: "status_too_long"
        }, 400);
      }

      const now = Date.now();

      await env.DB.prepare(`
        INSERT INTO bloom_status (
          user_id,
          text,
          updated_at
        )
        VALUES (?, ?, ?)
        ON CONFLICT(user_id)
        DO UPDATE SET
          text = excluded.text,
          updated_at = excluded.updated_at
      `).bind(
        userId,
        text,
        now
      ).run();

      return json({
        ok: true,
        status: {
          user_id: userId,
          text,
          updated_at: now
        }
      });
    }


    if (request.method === "DELETE" && url.pathname === "/api/profile/status") {
      const userId = String(
        url.searchParams.get("user_id") ?? ""
      ).trim();

      if (!userId) {
        return json({ ok: false, error: "user_id_required" }, 400);
      }

      await env.DB.prepare(`
        DELETE FROM bloom_status
        WHERE user_id = ?
      `).bind(userId).run();

      return json({
        ok: true
      });
    }


    // =========================
    // BLOOM R2 MEDIA
    // =========================

    if (request.method === "PUT" && url.pathname === "/api/media") {
      const userId = url.searchParams.get("user_id");
      const type = url.searchParams.get("type") || "profile";

      if (!userId) {
        return json({
          ok: false,
          error: "user_id_required"
        }, 400);
      }

      const user = await env.DB.prepare(`
        SELECT id
        FROM users
        WHERE id = ?
        LIMIT 1
      `).bind(userId).first();

      if (!user) {
        return json({
          ok: false,
          error: "user_not_found"
        }, 404);
      }

      if (!["profile", "background"].includes(type)) {
        return json({
          ok: false,
          error: "invalid_media_type"
        }, 400);
      }

      const contentType =
        request.headers.get("content-type") || "application/octet-stream";

      const allowedTypes = [
        "image/jpeg",
        "image/png",
        "image/webp"
      ];

      if (!allowedTypes.includes(contentType.toLowerCase())) {
        return json({
          ok: false,
          error: "unsupported_media_type"
        }, 415);
      }

      const body = await request.arrayBuffer();

      if (!body.byteLength) {
        return json({
          ok: false,
          error: "empty_media"
        }, 400);
      }

      // Batas 10 MB untuk foto profil/background.
      if (body.byteLength > 10 * 1024 * 1024) {
        return json({
          ok: false,
          error: "media_too_large"
        }, 413);
      }

      const extension = contentType.toLowerCase() === "image/png"
        ? "png"
        : contentType.toLowerCase() === "image/webp"
          ? "webp"
          : "jpg";

      const key = `users/${userId}/${type}.${extension}`;

      await env.MEDIA.put(key, body, {
        httpMetadata: {
          contentType
        }
      });

      const mediaUrl =
        `${url.origin}/api/media/${encodeURIComponent(key)}`;

      return json({
        ok: true,
        key,
        url: mediaUrl,
        type,
        content_type: contentType,
        size: body.byteLength
      });
    }

    if (
      request.method === "GET" &&
      url.pathname.startsWith("/api/media/")
    ) {
      const key = decodeURIComponent(
        url.pathname.substring("/api/media/".length)
      );

      if (!key) {
        return json({
          ok: false,
          error: "media_key_required"
        }, 400);
      }

      const object = await env.MEDIA.get(key);

      if (!object) {
        return json({
          ok: false,
          error: "media_not_found"
        }, 404);
      }

      const headers = new Headers();

      object.writeHttpMetadata(headers);
      headers.set("etag", object.httpEtag);
      headers.set("cache-control", "public, max-age=31536000, immutable");

      return new Response(object.body, {
        headers
      });
    }

    return json({
      ok: false,
      error: "not_found"
    }, 404);
  }
};


async function hashPin(pin) {
  const data = new TextEncoder().encode(pin);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");
}

async function verifyPin(pin, storedHash) {
  const hash = await hashPin(pin);
  return hash === storedHash;
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET,POST,PUT,DELETE,OPTIONS",
      "access-control-allow-headers": "Content-Type"
    }
  });
}
