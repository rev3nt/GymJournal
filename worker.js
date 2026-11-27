export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/index.html") {
      url.pathname = "/";
      return Response.redirect(url.toString(), 301);
    }

    if (url.pathname === "/") {
      const assetUrl = new URL(request.url);
      assetUrl.pathname = "/index.html";
      return env.ASSETS.fetch(new Request(assetUrl, request));
    }

    return env.ASSETS.fetch(request);
  },
};
