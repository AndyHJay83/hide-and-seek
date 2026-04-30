export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'Missing ANTHROPIC_API_KEY on server.' });
  }

  try {
    const incoming = req.body || {};
    const imageData = (((incoming.messages || [])[0] || {}).content || []).find((c) => c && c.type === 'image');
    if (!imageData || !imageData.source || !imageData.source.data) {
      return res.status(400).json({ error: 'Invalid request body: missing image base64.' });
    }

    const payload = {
      model: incoming.model || 'claude-sonnet-4-20250514',
      max_tokens: typeof incoming.max_tokens === 'number' ? incoming.max_tokens : 280,
      system: incoming.system || 'You are reading playing card indices from a photo. List every card you can clearly read from left to right, using short notation: AS, KH, 10C, 2D etc. Black suits are spades and clubs, red suits are hearts and diamonds. Use colour to confirm the suit. Only return the card list, nothing else, comma separated.',
      messages: incoming.messages
    };

    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify(payload)
    });

    const data = await r.json().catch(() => ({}));
    if (!r.ok) {
      const msg = (data && data.error && data.error.message) ? data.error.message : 'Anthropic request failed';
      return res.status(r.status).json({ error: msg });
    }

    const text = (((data || {}).content || [])[0] || {}).text || '';
    return res.status(200).json({ text, raw: data });
  } catch (err) {
    return res.status(500).json({ error: err && err.message ? err.message : 'Unexpected server error' });
  }
}
