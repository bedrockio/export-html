const Router = require("@koa/router");
const Koa = require("koa");
const { koaBody } = require('koa-body');
const validate = require("./utils/middleware/validate");
const errorHandler = require("./utils/middleware/error-handler");
const Sentry = require("@sentry/node");
const { version } = require("../package.json");
const config = require("@bedrockio/config");
const { loggingMiddleware } = require("@bedrockio/instrumentation");

const Joi = require("joi");

const { getBrowser, getPageCount } = require("./utils/browser");

const app = new Koa();

if (
  config.has("SENTRY_DSN") &&
  !["test", "development"].includes(process.env.ENV_NAME)
) {
  Sentry.init({
    dsn: config.get("SENTRY_DSN"),
    environment: process.env.ENV_NAME,
  });
}

app
  .use(koaBody({ multipart: true }))
  .use(loggingMiddleware())
  .use(errorHandler)
  .use(require('koa-simple-healthcheck')());

const router = new Router();
app.router = router;

router.get("/", (ctx) => {
  ctx.body = {
    environment: config.get("ENV_NAME"),
    version,
    servedAt: new Date(),
  };
});

router.get("/check-status", async (ctx) => {
  ctx.body = {
    pageCount: await getPageCount(),
  };
});

// https://pptr.dev/#?product=Puppeteer&version=v8.0.0&show=api-pagescreenshotoptions
router.get(
  "/1/screenshot",
  validate({
    query: Joi.object({
      url: Joi.string().required(),
      type: Joi.string().allow("jpeg", "png", "webp").default("png"),
    }),
  }),
  async (ctx) => {
    const query = ctx.request.query;
    const browser = await getBrowser();
    const page = await browser.newPage();

    await page.goto(query.url, { waitUntil: "load" });
    
    const options = {
      type: query.type
    };

    ctx.response.set("content-type", `image/${query.type}`);
    ctx.body = await page.screenshot(options);

    await page.close();
  }
);

// https://pptr.dev/#?product=Puppeteer&version=v8.0.0&show=api-pagescreenshotoptions
router.post(
  "/1/screenshot",
  validate({
    body: Joi.object({
      html: Joi.string(),
      url: Joi.string(),
      export: Joi.object({
        scale: Joi.number().min(0.1).max(2).default(1),
        type: Joi.string().allow("jpeg", "png", "webp").default("png"),
        quality: Joi.number().min(0).max(100).default(100),
        fullPage: Joi.boolean().default(true),
        clip: Joi.object({
          x: Joi.number(),
          y: Joi.number(),
          width: Joi.number(),
          height: Joi.number(),
        }),
        omitBackground: Joi.boolean().default(false),
        encoding: Joi.string().allow("base64", "binary").default("binary"),
      }),
    }).or('html', 'url'),
  }),
  async (ctx) => {
    const body = ctx.request.body;
    const browser = await getBrowser();
    const page = await browser.newPage();
    
    if(body.url) {
      await page.goto(body.url, { waitUntil: "load" });
    } else {
      await page.setContent(body.html, { waitUntil: "load" });
    }
    
    const options = body.export;
    if (options.type === "png") {
      delete options.quality;
    }
    ctx.response.set("content-type", `image/${options.type}`);
    ctx.body = await page.screenshot(options);

    await page.close();
  }
);

// https://pptr.dev/#?product=Puppeteer&version=v8.0.0&show=api-pagepdfoptions
router.post(
  "/1/pdf",
  validate({
    body: Joi.object({
      html: Joi.string().required(),
      export: Joi.object({
        scale: Joi.number().default(1),
        displayHeaderFooter: Joi.boolean().default(true),
        headerTemplate: Joi.string(),
        footerTemplate: Joi.string(),
        printBackground: Joi.boolean().default(true),
        landscape: Joi.boolean().default(false),
        pageRanges: Joi.string(),
        width: Joi.string(),
        height: Joi.string(),
        format: Joi.string()
          .valid(
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
        margin: Joi.object({
          top: Joi.string(),
          right: Joi.string(),
          bottom: Joi.string(),
          left: Joi.string(),
        }),
        preferCSSPageSize: Joi.boolean().default(false),
      }),
    }),
  }),
  async (ctx) => {
    const body = ctx.request.body;
    const browser = await getBrowser();
    const page = await browser.newPage();

    await page.setContent(body.html, { waitUntil: "load" });
    ctx.body = await page.pdf(body.export);
    await page.close();
  }
);

app.use(router.routes());
app.use(router.allowedMethods());

app.on("error", (err, ctx) => {
  // dont output stacktraces of errors that is throw with status as they are known
  if (!err.status || err.status === 500) {
    ctx.logger.error(err);
    Sentry.withScope(function (scope) {
      scope.addEventProcessor(function (event) {
        return Sentry.Handlers.parseRequest(event, ctx.request);
      });
      Sentry.captureException(err);
    });
  }
});

module.exports = app;
