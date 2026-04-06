const fastify = require("fastify")({ logger: true });
const cors = require("@fastify/cors");
const { v4: uuidv4 } = require("uuid");
const { PKPass } = require("passkit-generator");
const fs = require("fs");
const path = require("path");

// ── Config ──────────────────────────────────────────────────
const PORT = process.env.PORT || 3939;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY || "";

// Apple Wallet cert paths (you'll generate these)
const CERTS_DIR = path.join(__dirname, "certs");
const PASS_MODEL_DIR = path.join(__dirname, "pass-model");

// ── Plugins ─────────────────────────────────────────────────
fastify.register(cors, { origin: true });

// ── Health check ────────────────────────────────────────────
fastify.get("/", async () => ({
  service: "ndpass-server",
  status: "ok",
  features: {
    parse: !!ANTHROPIC_API_KEY,
    wallet: fs.existsSync(path.join(CERTS_DIR, "signerCert.pem")),
  },
}));

// ── POST /parse — Proxy ticket image to Claude Vision ───────
// The app sends the image here instead of calling Anthropic directly.
// This keeps the API key off the device.
fastify.post("/parse", async (request, reply) => {
  if (!ANTHROPIC_API_KEY) {
    return reply.code(500).send({ error: "ANTHROPIC_API_KEY not configured" });
  }

  const { image, mediaType } = request.body;
  // image: base64 string, mediaType: "image/jpeg" | "image/png"

  if (!image || !mediaType) {
    return reply.code(400).send({ error: "Missing image or mediaType" });
  }

  const prompt = `You are a movie ticket parser. Analyze this image of a movie ticket and extract the following information. Return ONLY valid JSON, no markdown, no backticks, no explanation.

{
  "movieTitle": "exact movie title shown on ticket",
  "theater": "theater/cinema name",
  "date": "YYYY-MM-DD format, infer year if not shown (use current year)",
  "time": "h:mm AM/PM format",
  "seat": "seat/row info if visible, or null",
  "price": "price with $ if visible, or null",
  "confidence": 0.95
}

Rules:
- If a field is illegible or missing, use your best guess and lower the confidence score
- For date, always output ISO format YYYY-MM-DD
- For time, always output 12-hour with AM/PM
- confidence is 0-1 representing how sure you are about ALL extracted fields
- If this is NOT a movie ticket, return {"error": "not_a_ticket", "confidence": 0}`;

  try {
    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 512,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: { type: "base64", media_type: mediaType, data: image },
              },
              { type: "text", text: prompt },
            ],
          },
        ],
      }),
    });

    if (!resp.ok) {
      const errText = await resp.text();
      return reply
        .code(resp.status)
        .send({ error: `Anthropic API: ${errText}` });
    }

    const data = await resp.json();
    const text = data.content?.[0]?.text ?? "";
    const cleaned = text.replace(/```json\n?|```/g, "").trim();
    const parsed = JSON.parse(cleaned);

    return parsed;
  } catch (err) {
    fastify.log.error(err);
    return reply.code(500).send({ error: err.message });
  }
});

// ── POST /pass — Generate an Apple Wallet .pkpass ───────────
fastify.post("/pass", async (request, reply) => {
  const { movieTitle, theater, date, time, seat, price } = request.body;

  if (!movieTitle || !theater || !date || !time) {
    return reply
      .code(400)
      .send({ error: "Missing required fields: movieTitle, theater, date, time" });
  }

  // Check if certs exist
  const signerCert = path.join(CERTS_DIR, "signerCert.pem");
  const signerKey = path.join(CERTS_DIR, "signerKey.pem");
  const wwdr = path.join(CERTS_DIR, "wwdr.pem");

  if (!fs.existsSync(signerCert) || !fs.existsSync(signerKey)) {
    return reply.code(501).send({
      error: "Apple Wallet certs not configured yet",
      setup:
        "See server/README.md for cert generation instructions",
    });
  }

  try {
    const pass = new PKPass(
      {},
      {
        wwdr: fs.readFileSync(wwdr),
        signerCert: fs.readFileSync(signerCert),
        signerKey: fs.readFileSync(signerKey),
        signerKeyPassphrase: process.env.SIGNER_KEY_PASSPHRASE || "",
      },
      {
        serialNumber: uuidv4(),
        description: `${movieTitle} — ${theater}`,
        organizationName: "NDPass",
        passTypeIdentifier: process.env.PASS_TYPE_ID || "pass.com.gios.ndpass",
        teamIdentifier: process.env.APPLE_TEAM_ID || "",
        foregroundColor: "rgb(232, 213, 183)",
        backgroundColor: "rgb(10, 10, 10)",
        labelColor: "rgb(138, 132, 120)",
      }
    );

    pass.type = "eventTicket";

    pass.headerFields.push({
      key: "time",
      label: "TIME",
      value: time,
    });

    pass.primaryFields.push({
      key: "movie",
      label: "FILM",
      value: movieTitle,
    });

    pass.secondaryFields.push(
      {
        key: "theater",
        label: "THEATER",
        value: theater,
      },
      {
        key: "date",
        label: "DATE",
        value: date,
      }
    );

    if (seat) {
      pass.auxiliaryFields.push({
        key: "seat",
        label: "SEAT",
        value: seat,
      });
    }

    if (price) {
      pass.auxiliaryFields.push({
        key: "price",
        label: "PRICE",
        value: price,
      });
    }

    // Set relevance — show on lock screen near showtime
    const [year, month, day] = date.split("-").map(Number);
    const timeMatch = time.match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
    if (timeMatch) {
      let hours = parseInt(timeMatch[1]);
      const minutes = parseInt(timeMatch[2]);
      const ampm = timeMatch[3].toUpperCase();
      if (ampm === "PM" && hours !== 12) hours += 12;
      if (ampm === "AM" && hours === 12) hours = 0;
      pass.relevantDate = new Date(year, month - 1, day, hours, minutes);
    }

    const buffer = pass.getAsBuffer();

    reply
      .header("Content-Type", "application/vnd.apple.pkpass")
      .header(
        "Content-Disposition",
        `attachment; filename="${movieTitle.replace(/[^a-zA-Z0-9]/g, "_")}.pkpass"`
      )
      .send(buffer);
  } catch (err) {
    fastify.log.error(err);
    return reply.code(500).send({ error: err.message });
  }
});

// ── Start ───────────────────────────────────────────────────
fastify.listen({ port: PORT, host: "0.0.0.0" }, (err) => {
  if (err) {
    fastify.log.error(err);
    process.exit(1);
  }
  console.log(`NDPass server running on :${PORT}`);
});
