import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";

const base = process.env.NEXUS_URL || "http://127.0.0.1:5173";
const cfg = await readFile(
  new URL("../.nexus-local/config.json", import.meta.url),
  "utf8",
)
  .then(JSON.parse)
  .catch(() => ({}));
const adminEmail = process.env.NEXUS_ADMIN_EMAIL || cfg.adminEmail;
const adminPassword = process.env.NEXUS_ADMIN_PASSWORD || cfg.adminPassword;
assert(
  adminEmail && adminPassword,
  "Configura NEXUS_ADMIN_EMAIL y NEXUS_ADMIN_PASSWORD",
);
const marca = randomUUID().slice(0, 12);
const email = "prueba-" + marca + "@example.com";
const password = randomUUID() + "Aa!";
async function api(ruta, { method = "GET", token, body, status = 200 } = {}) {
  const headers = { Accept: "application/json" };
  if (token) headers.Authorization = "Bearer " + token;
  if (body) headers["Content-Type"] = "application/json";
  const res = await fetch(base + "/api/v1/" + ruta, {
    method,
    headers,
    body: body && JSON.stringify(body),
    signal: AbortSignal.timeout(30000),
  });
  const text = await res.text();
  if (res.status !== status)
    throw new Error(
      method +
        " " +
        ruta +
        " devolvió " +
        res.status +
        " (esperado " +
        status +
        ")",
    );
  return text ? JSON.parse(text) : null;
}
const admin = await api("auth/login", {
  method: "POST",
  body: { email: adminEmail, password: adminPassword },
});
const producto = await api("productos", {
  method: "POST",
  token: admin.token,
  status: 201,
  body: {
    nombre: "Prueba " + marca,
    precio: 5000,
    precioOferta: 4000,
    stock: 3,
    categoria: "Pruebas",
  },
});
try {
  const registro = await api("auth/register", {
    method: "POST",
    status: 201,
    body: { email, password, nombre: "Cliente de prueba" },
  });
  const { token, usuarioId } = await api("auth/login", {
    method: "POST",
    body: { email, password },
  });
  assert.equal(registro.usuarioId, usuarioId);
  assert.equal((await api("usuarios/" + usuarioId, { token })).email, email);
  const perfil = await api("usuarios/" + usuarioId, {
    method: "PATCH",
    token,
    body: { nombre: "Perfil editado", biografia: "Nexus" },
  });
  assert.equal(perfil.biografia, "Nexus");
  assert((await api("productos")).some((p) => p.id === producto.id));
  const pedido = {
    usuarioId,
    solicitudId: randomUUID(),
    tipoEntrega: "domicilio",
    direccionEntrega: "Calle de prueba, Paine",
    nombreContacto: "Cliente de prueba",
    correoContacto: email,
    metodoPago: "TARJETA",
    items: [{ productoId: producto.id, cantidad: 2 }],
  };
  await api("pedidos", {
    method: "POST",
    token,
    status: 409,
    body: {
      ...pedido,
      solicitudId: randomUUID(),
      items: [{ productoId: producto.id, cantidad: 4 }],
    },
  });
  assert.equal((await api("productos/" + producto.id)).stock, 3);
  const crear = () =>
    api("pedidos", { method: "POST", body: pedido, token, status: 201 });
  const [orden, repeticion] = await Promise.all([crear(), crear()]);
  assert.equal(repeticion.id, orden.id);
  assert.equal(orden.total, 11990);
  assert.equal(orden.items[0].precioUnitario, 4000);
  assert(orden.referenciaPago);
  assert.equal(repeticion.referenciaPago, orden.referenciaPago);
  assert.equal((await api("productos/" + producto.id)).stock, 1);
  assert.equal(
    (await api("pedidos/usuario/" + usuarioId, { token })).length,
    1,
  );
  let stockInventario;
  for (let intento = 0; intento < 20; intento++) {
    const inventario = await api("inventario", { token: admin.token });
    stockInventario = inventario.find(
      (i) => i.productoId === producto.id,
    )?.stockActual;
    if (stockInventario === 1) break;
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  assert.equal(
    stockInventario,
    1,
    "El inventario debe reflejar el stock confirmado",
  );
  assert.equal(
    (await api("pagos/pedido/" + orden.id, { token: admin.token })).length,
    1,
  );
  await api("usuarios", { token, status: 403 });
  const confirmado = await api(
    "pedidos/" + orden.id + "/estado?estado=CONFIRMADO",
    { method: "PATCH", token: admin.token },
  );
  assert.equal(confirmado.estado, "CONFIRMADO");
  console.log(
    "OK · catálogo, registro, login, perfil, oferta, despacho, falta de stock, pedido, pago simulado, reintento, historial, inventario y administración.",
  );
} finally {
  await api("productos/" + producto.id, {
    method: "DELETE",
    token: admin.token,
    status: 204,
  });
}
