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

      try {
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
      } catch (error) {
        return json({
          ok: false,
          error: "register_database_error",
          message: String(error?.message ?? error),
          name: String(error?.name ?? "Error")
        }, 500);
      }

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
          created_at: user.created_at
        }
      });
    }

    // =========================
    // BLOOM ACCOUNT / PROFILE
    // =========================

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
