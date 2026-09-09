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

  // ── Keuangan K1 — kategori pengeluaran bawaan + contoh ──
  const expCats = [
    { name: 'Operasional', group: 'OPERATING', sort: 10 },
    { name: 'Gaji & Upah', group: 'OPERATING', sort: 20 },
    { name: 'Sewa Tempat', group: 'OPERATING', sort: 30 },
    { name: 'Utilitas (Listrik/Air/Internet)', group: 'OPERATING', sort: 40 },
    { name: 'Bahan Habis Pakai', group: 'OPERATING', sort: 50 },
    { name: 'Marketing', group: 'OPERATING', sort: 60 },
    { name: 'Perbaikan & Perawatan', group: 'OPERATING', sort: 70 },
    { name: 'Belanja Peralatan & Aset', group: 'INVESTING', sort: 80 },
    { name: 'Lain-lain', group: 'OPERATING', sort: 999 },
  ];
  const slugify = (s: string) =>
    s.toLowerCase().replace(/[()/]/g, ' ').replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '').slice(0, 60);
  await prisma.expenseCategory.createMany({
    data: expCats.map((c) => ({
      id: randomUUID(),
      tenantId: tenant.id,
      name: c.name,
      slug: slugify(c.name),
      cashflowGroup: c.group,
      sortOrder: c.sort,
    })),
  });
  const catRows = await prisma.expenseCategory.findMany({ where: { tenantId: tenant.id } });
  const catId = (re: RegExp) => catRows.find((c) => re.test(c.name))!.id;
  const adminUser = await prisma.user.findFirstOrThrow({
    where: { tenantId: tenant.id, username: 'admin' },
  });
  const now = new Date();
  const dISO = (offsetDays: number) => {
    const d = new Date(now);
    d.setDate(d.getDate() - offsetDays);
    return d;
  };
  const demoExpenses = [
    { title: 'Gaji karyawan bulan ini', amount: 8_000_000, cat: /Gaji/, pm: 'TRANSFER', off: 4 },
    { title: 'Sewa outlet', amount: 8_000_000, cat: /Sewa/, pm: 'TRANSFER', off: 5 },
    { title: 'Tagihan listrik & air', amount: 3_600_000, cat: /Utilitas/, pm: 'TRANSFER', off: 6 },
    { title: 'Cup, sedotan, tissue', amount: 1_250_000, cat: /Bahan Habis/, pm: 'CASH', off: 7 },
    { title: 'Iklan IG + promo GoFood', amount: 2_000_000, cat: /Marketing/, pm: 'CARD', off: 8 },
    { title: 'Servis mesin kopi', amount: 750_000, cat: /Perbaikan/, pm: 'CASH', off: 8 },
    { title: 'Beli galon & es batu', amount: 120_000, cat: /Operasional/, pm: 'CASH', off: 1 },
    { title: 'Beli blender baru', amount: 1_400_000, cat: /Peralatan/, pm: 'CARD', off: 3 },
  ];
  let expSeq = 0;
  for (const e of demoExpenses) {
    await prisma.expense.create({
      data: {
        tenantId: tenant.id,
        branchId: branchPusat.id,
        expenseNumber: `EXP-${now.getFullYear()}-${String(++expSeq).padStart(6, '0')}`,
        title: e.title,
        amount: e.amount,
        categoryId: catId(e.cat),
        paymentMethod: e.pm as any,
        expenseDate: dISO(e.off),
        createdById: adminUser.id,
      },
    });
  }

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
