import 'dotenv/config';
import { PrismaClient, type UserRole } from '@prisma/client';
import bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';

const prisma = new PrismaClient();

async function main() {
  console.log('[seed] mulai seeding data...');

  const tenantExists = await prisma.tenant.count({
    where: { slug: 'demo-fnb' },
  });
  if (tenantExists > 0) {
    console.log('[seed] tenant demo-fnb sudah ada, skip.');
    await prisma.$disconnect();
    return;
  }

  const hashed = await bcrypt.hash('admin123', 10);
  const hashedCashier = await bcrypt.hash('kasir123', 10);

  await prisma.tenant.create({
    data: {
      id: randomUUID(),
      slug: 'demo-fnb',
      name: 'Restoran Demo F&B',
      address: 'Jl. Makan Enak No. 12, Jakarta',
      phone: '021-12345678',
      receiptFooter: 'Terima kasih atas kunjungan Anda!',
      taxSettings: {
        enabled: true,
        rate: 11,
        pricesIncludeTax: true,
      },
      allowPayAtCashier: true,
      allowedSolutions: ['FNB_POS'],
      branches: {
        create: {
          id: randomUUID(),
          name: 'Cabang Pusat',
        },
      },
    },
    include: { branches: true },
  });

  const tenant = await prisma.tenant.findUniqueOrThrow({
    where: { slug: 'demo-fnb' },
    include: { branches: true },
  });
  const branchPusat = tenant.branches[0];

  await prisma.user.createMany({
    data: [
      {
        id: randomUUID(),
        tenantId: tenant.id,
        branchId: branchPusat.id,
        username: 'admin',
        passwordHash: hashed,
        role: 'TENANT_ADMIN' as UserRole,
        isActive: true,
      },
      {
        id: randomUUID(),
        tenantId: tenant.id,
        branchId: branchPusat.id,
        username: 'kasir',
        passwordHash: hashedCashier,
        role: 'CASHIER' as UserRole,
        isActive: true,
      },
      {
        id: randomUUID(),
        tenantId: tenant.id,
        branchId: branchPusat.id,
        username: 'migrasi',
        passwordHash: 'oldpass123',
        role: 'CASHIER' as UserRole,
        isActive: true,
      },
    ],
  });

  const categories = ['Makanan Utama', 'Minuman', 'Camilan', 'Dessert'];
  await prisma.category.createMany({
    data: categories.map((name, idx) => ({
      id: randomUUID(),
      tenantId: tenant.id,
      name,
      sortOrder: idx,
      isActive: true,
    })),
  });

  const sampleProducts = [
    { name: 'Nasi Goreng Spesial', category: 'Makanan Utama', price: 35000, stock: 100 },
    { name: 'Ayam Geprek', category: 'Makanan Utama', price: 28000, stock: 80 },
    { name: 'Es Teh Manis', category: 'Minuman', price: 5000, stock: 200 },
    { name: 'Es Jeruk', category: 'Minuman', price: 8000, stock: 150 },
    { name: 'Kentang Goreng', category: 'Camilan', price: 15000, stock: 120 },
    { name: 'Puding Cokelat', category: 'Dessert', price: 12000, stock: 60 },
  ];

  await prisma.product.createMany({
    data: sampleProducts.map((p) => ({
      id: randomUUID(),
      tenantId: tenant.id,
      branchId: branchPusat.id,
      name: p.name,
      category: p.category,
      price: p.price,
      cost: p.price * 0.55,
      stock: p.stock,
      isActive: true,
    })),
  });

  console.log('[seed] ✅ SELESAI.');
  console.log('  tenantSlug : demo-fnb');
  console.log('  admin      : admin / admin123   (TENANT_ADMIN, bcrypt)');
  console.log('  cashier    : kasir / kasir123   (CASHIER, bcrypt)');
  console.log('  migrasi    : migrasi / oldpass123 (CASHIER, plaintext — uji fallback)');
  console.log(`  branchPusatId: ${branchPusat.id}`);
}

main()
  .catch((e) => {
    console.error('[seed] ERROR:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
