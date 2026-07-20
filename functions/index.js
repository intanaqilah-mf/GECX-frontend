'use strict';

const { https } = require('firebase-functions/v1');
const { GoogleAuth } = require('google-auth-library');
const fetch = require('node-fetch');

const TARGET_BASE = 'https://customer-platform-api-483471568825.us-central1.run.app';
const ALLOWED_ORIGIN = 'https://emvnzir-canada-song.web.app';

exports.api = https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const auth = new GoogleAuth();
    const client = await auth.getIdTokenClient(TARGET_BASE);
    const authHeaders = await client.getRequestHeaders();

    const queryString = new URLSearchParams(req.query).toString();
    const targetUrl = `${TARGET_BASE}${req.path}${queryString ? '?' + queryString : ''}`;

    const fetchOptions = {
      method: req.method,
      headers: {
        'Authorization': authHeaders['Authorization'],
        'Content-Type': req.headers['content-type'] || 'application/json',
      },
    };

    if (req.method !== 'GET' && req.method !== 'HEAD' && req.body && Object.keys(req.body).length > 0) {
      fetchOptions.body = JSON.stringify(req.body);
    }

    const upstream = await fetch(targetUrl, fetchOptions);
    const body = await upstream.text();

    upstream.headers.forEach((value, key) => {
      if (!['transfer-encoding', 'connection', 'content-encoding'].includes(key.toLowerCase())) {
        res.set(key, value);
      }
    });

    res.status(upstream.status).send(body);
  } catch (err) {
    console.error('Proxy error:', err);
    res.status(502).json({ error: 'Proxy error', details: err.message });
  }
});
