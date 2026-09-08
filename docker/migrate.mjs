import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';

if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
try {
  const db = drizzle(pool);
  await migrate(db, {
    migrationsFolder: './drizzle-auth',
    migrationsSchema: 'drizzle',
    migrationsTable: '__drizzle_auth_migrations',
  });
  await migrate(db, {
    migrationsFolder: './drizzle',
    migrationsSchema: 'drizzle',
    migrationsTable: '__drizzle_migrations',
  });
  console.log('Better Auth and business database migrations completed.');
} finally {
  await pool.end();
}
