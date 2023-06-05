const puppeteer = require("puppeteer");

let browserWSEndpoint;
async function getBrowserWebsocket() {
  if (browserWSEndpoint) return browserWSEndpoint;

  const browser = await puppeteer.launch({
    args: ["--no-sandbox", "--disable-dev-shm-usage"],
    devtools: false,
    dumpio: false, // TURN THIS ON IF puppeteer.launch() is stuck without details
    headless: 'new'
  });

  browserWSEndpoint = browser.wsEndpoint();
  browser.disconnect();
  return browserWSEndpoint;
}

let browser;
async function getBrowser() {
  if (browser) return browser;
  const browserWSEndpoint = await getBrowserWebsocket();

  browser = await puppeteer.connect({ browserWSEndpoint });
  return browser;
}

exports.getBrowser = getBrowser;

exports.getPageCount = async function getPageCount() {
  const browser = await getBrowser();
  const openPages = await browser.pages();
  return openPages.length;
};
