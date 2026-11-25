import { randomBytes } from "node:crypto";
import { writeFile } from "node:fs/promises";

const generar = () => randomBytes(32).toString("hex");
const archivo = new URL("../.env", import.meta.url);
const contenido = [
  "MYSQL_USERNAME=root",
  "MYSQL_ROOT_PASSWORD=" + generar(),
  "JWT_SECRET=" + generar(),
  "NEXUS_ADMIN_EMAIL=admin@nexus.local",
  "NEXUS_ADMIN_PASSWORD=" + generar(),
  "",
].join("\n");

try {
  await writeFile(archivo, contenido, { flag: "wx", mode: 0o600 });
  console.log("Configuración local creada en .env. Allí encontrarás el acceso administrativo.");
} catch (error) {
  if (error.code !== "EEXIST") throw error;
  console.log("Ya existe .env. Se conserva su configuración.");
}
