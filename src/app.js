const Router = require("@koa/router");
const Koa = require("koa");
const bodyParser = require("koa-body").default;
const errorHandler = require("./utils/middleware/error-handler");
const { validateBody } = require("./utils/middleware/validate");

const logger = require("@bedrockio/logger");

const { getBrowser, getPageCount } = require("./utils/browser");
const yd = require("@bedrockio/yada");

function urlCustom(value, { root }) {
  if ((value && root.html) || (!value && !root.html)) {
    throw new Error("Either url or html is required");
  }
}

function htmlCustom(value, { root }) {
  if ((value && root.url) || (!value && !root.url)) {
    throw new Error("Either url or html is required");
  }
}

const app = new Koa();

app
  .use(errorHandler)
  .use(logger.middleware())
  .use(bodyParser({ multipart: true }));

const router = new Router();
app.router = router;

router.get("/", (ctx) => {
  ctx.body = {
    servedAt: new Date(),
  };
});

router.get("/check-status", async (ctx) => {
  ctx.body = {
    pageCount: await getPageCount(),
  };
});

// https://pptr.dev/#?product=Puppeteer&version=v8.0.0&show=api-pagescreenshotoptions
router.post(
  "/1/screenshot",
  validateBody({
    url: yd.custom(urlCustom),
    html: yd.string().custom(htmlCustom),
    export: yd
      .object({
        scale: yd.number().min(0.1).max(2).default(1),
        type: yd.string().allow("jpeg", "png", "webp").default("png"),
        quality: yd.number().min(0).max(100).default(100),
        fullPage: yd.boolean().default(true),
        fromSurface: yd.boolean().default(true),
        clip: yd.object({
          x: yd.number(),
          y: yd.number(),
          width: yd.number(),
          height: yd.number(),
        }),
        omitBackground: yd.boolean().default(false),
        encoding: yd.string().allow("base64", "binary").default("binary"),
        viewport: yd.object({
          width: yd.number().default(800),
          height: yd.number().default(600),
          deviceScaleFactory: yd.number().default(1),
          hasTouch: yd.boolean().default(false),
          isLandscape: yd.boolean().default(false),
          isMobile: yd.boolean().default(false),
        }),
      })
      .default({
        scale: 1,
        type: "png",
        quality: 100,
        fullPage: true,
        omitBackground: false,
        encoding: "binary",
      }),
  }),
  async (ctx) => {
    const body = ctx.request.body;
    const browser = await getBrowser();
    const page = await browser.newPage();

    if (body.export.viewport) {
      await page.setViewport(body.export.viewport);
      delete body.export.viewport;
    }

    if (body.url) {
      await page.goto(body.url, { waitUntil: "load" });
    } else {
      await page.setContent(body.html, { waitUntil: "load" });
    }
    const options = body.export;
    if (options.type === "png") {
      delete options.quality;
    }
    ctx.response.set("content-type", `image/${options.type}`);
    ctx.body = await page.screenshot(options).finally(() => page.close());
  }
);

// https://pptr.dev/#?product=Puppeteer&version=v8.0.0&show=api-pagepdfoptions
router.post(
  "/1/pdf",
  validateBody({
    url: yd.custom(urlCustom),
    html: yd.string().custom(htmlCustom),
    export: yd.object({
      scale: yd.number().default(1),
      displayHeaderFooter: yd.boolean().default(true),
      headerTemplate: yd.string(),
      footerTemplate: yd.string(),
      timeout: yd.number().default(30000),
      omitBackground: yd.boolean().default(false),
      printBackground: yd.boolean().default(false),
      outline: yd.boolean().default(false),
      landscape: yd.boolean().default(false),
      pageRanges: yd.string(),
      width: yd.string(),
      height: yd.string(),
      format: yd
        .string()
        .allow(
          "Letter",
          "Legal",
          "Tabloid",
          "Ledger",
          "A0",
          "A1",
          "A2",
          "A3",
          "A4",
          "A5",
          "A6"
        )
        .default("Letter"),
      margin: yd.object({
        top: yd.string(),
        right: yd.string(),
        bottom: yd.string(),
        left: yd.string(),
      }),
      preferCSSPageSize: yd.boolean().default(false),
    }),
  }),
  async (ctx) => {
    const body = ctx.request.body;
    const browser = await getBrowser();
    const page = await browser.newPage();

    if (body.url) {
      await page.goto(body.url, { waitUntil: "load" });
    } else {
      await page.setContent(body.html, { waitUntil: "load" });
    }
    ctx.body = await page.pdf(body.export).finally(() => page.close());
  }
);

app.use(router.routes());
app.use(router.allowedMethods());

app.on("error", (err, ctx) => {
  // dont output stacktraces of errors that is throw with status as they are known
  if (!err.status || err.status === 500) {
    logger.error(err);
  }
});

module.exports = app;
