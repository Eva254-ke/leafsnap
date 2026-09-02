export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    
    // Only handle plant identification endpoint
    if (url.pathname === '/v1/identify/plant' && request.method === 'POST') {
      return handlePlantIdentify(request, env);
    }
    
    return new Response('Not Found', { status: 404 });
  }
};

async function handlePlantIdentify(request, env) {
  const plantnetApiKey = env.PLANTNET_API_KEY;
  
  if (!plantnetApiKey) {
    return new Response('Missing PLANTNET_API_KEY', { status: 500 });
  }

  try {
    const formData = await request.formData();
    
    const url = 'https://my-api.plantnet.org/v2/identify/all';
    const params = new URLSearchParams({
      'api-key': plantnetApiKey,
      'include-related-images': 'false',
      'no-reject': 'true',
      'nb-results': '3'
    });

    const response = await fetch(`${url}?${params}`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      return new Response(await response.text(), {
        status: response.status,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const data = await response.json();
    return new Response(JSON.stringify(data), {
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}
