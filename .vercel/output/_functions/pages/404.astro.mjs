/* empty css                                  */
import { c as createComponent, r as renderComponent, a as renderTemplate, m as maybeRenderHead } from '../chunks/astro/server_CUMT7Dv3.mjs';
import 'piccolore';
import { $ as $$Layout } from '../chunks/Layout_DqQfhmns.mjs';
export { renderers } from '../renderers.mjs';

const $$404 = createComponent(($$result, $$props, $$slots) => {
  return renderTemplate`${renderComponent($$result, "Layout", $$Layout, { "title": "404 - Sayfa Bulunamad\u0131" }, { "default": ($$result2) => renderTemplate` ${maybeRenderHead()}<main class="min-h-screen flex flex-col items-center justify-center p-4 text-center"> <h1 class="text-6xl font-black text-palette-red mb-4">404</h1> <p class="text-xl text-palette-tan font-bold mb-8">Aradığınız haber veya sayfa bulunamadı.</p> <a href="/" class="px-8 py-3 bg-palette-tan text-white rounded-[5px] font-black tracking-widest hover:bg-palette-red transition-all">
ANA SAYFAYA DÖN
</a> </main> ` })}`;
}, "/Users/pateez/Desktop/pateeznews/src/pages/404.astro", void 0);

const $$file = "/Users/pateez/Desktop/pateeznews/src/pages/404.astro";
const $$url = "/404";

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
	__proto__: null,
	default: $$404,
	file: $$file,
	url: $$url
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
