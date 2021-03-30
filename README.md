# EXPORT HTML

** WARNING **

Don't expose this api publicly.

##Scaling:

This is running a full browser, if trigger too many parallel requests, it can cause the memory to spike.
Each request translates to opening a tab in your browser, after each request is completed the tab is closed.

##Features:

- Converts HTML content to a PDF file or an image (PNG/JPEG)
- Rendered with Headless Chrome, using [Puppeteer](https://github.com/GoogleChrome/puppeteer).
