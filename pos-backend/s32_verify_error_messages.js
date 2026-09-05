const http = require('http');

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const opts = {
      hostname: 'localhost',
      port: 3001,
      path: '/api/v1' + path,
      method,
      headers: {
        'Content-Type': 'application/json',
      }
    };
    if (token) opts.headers.Authorization = 'Bearer ' + token;
    if (data) opts.headers['Content-Length'] = Buffer.byteLength(data);
    const req = http.request(opts, (res) => {
      let chunks = '';
      res.on('data', (c) => chunks += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: chunks ? JSON.parse(chunks) : null }); }
        catch (e) { resolve({ status: res.statusCode, raw: chunks, error: 'JSON parse fail: ' + e.message }); }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

(async () => {
  const login = await request('POST', '/auth/login', { tenantSlug: 'demo-fnb', username: 'kasir', password: 'kasir123' });
  if (login.status !== 200 || !login.body.success) { console.log('LOGIN FAIL', login); process.exit(1); }
  const token = login.body.data.token;

  const prod = await request('GET', '/products', null, token);
  const list = prod.body.data.products;
  const p1 = list[0], p2 = list[1];
  const qty1 = 2, qty2 = 2;
  const sub = qty1*p1.price + qty2*p2.price;
  const tax = Math.round(sub*0.11*100)/100;
  const total = sub + tax;

  function pay(pm, ref, refId) {
    return request('POST', '/sales', {
      referenceId: refId, orderType: 'DINE_IN', paymentMethod: pm,
      subtotal: sub, discountAmount: 0, taxAmount: tax, serviceChargeAmount: 0, serviceChargePercentage: 0,
      total, items: [
        { productId: p1.id, productName: p1.name, qty: qty1, unitPrice: p1.price, lineTotal: qty1*p1.price },
        { productId: p2.id, productName: p2.name, qty: qty2, unitPrice: p2.price, lineTotal: qty2*p2.price }
      ], cashierId: login.body.data.user.id, branchId: login.body.data.user.branchId,
      paymentReferenceNumber: ref, cashReceived: total, cashChange: 0
    }, token);
  }

  const qrisNull = await pay('QRIS', null, require('crypto').randomUUID());
  console.log('[QRIS ref=null] status=' + qrisNull.status + ' | error=' + JSON.stringify(qrisNull.body?.error || qrisNull.raw));
  const ccEmpty = await pay('CREDIT_CARD', '', require('crypto').randomUUID());
  console.log('[CC ref=""]  status=' + ccEmpty.status + ' | error=' + JSON.stringify(ccEmpty.body?.error || ccEmpty.raw));

  const ok1 = qrisNull.status===400 && typeof qrisNull.body?.error === 'string' && qrisNull.body.error.includes('Nomor referensi QRIS');
  const ok2 = ccEmpty.status===400 && typeof ccEmpty.body?.error === 'string' && ccEmpty.body.error.includes('kartu kredit');
  console.log('\n=== VERIFY RESULT: ' + (ok1 && ok2 ? 'PASS' : 'FAIL') + ' ===');
  console.log('  [S32-AC4-2 QRIS message:] ' + (ok1 ? 'PASS' : 'FAIL'));
  console.log('  [S32-AC4-4 CC message:]   ' + (ok2 ? 'PASS' : 'FAIL'));
  process.exit(ok1 && ok2 ? 0 : 1);
})().catch(e => { console.error(e); process.exit(2); });
