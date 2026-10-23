import type { NextConfig } from "next";

// Security headers that do not depend on the host. They apply when Next serves the site (Node server or Vercel).
// A static export (for example Cloudflare Pages) ignores headers(); there the same values go in public/_headers or the
// host's settings, and HSTS belongs to the host's TLS config. No Content-Security-Policy yet: the theme script in
// layout.tsx is inline and needs a nonce or hash first.
const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=(), payment=(), usb=()" },
];

const nextConfig: NextConfig = {
  async headers() {
    return [{ source: "/(.*)", headers: securityHeaders }];
  },
};

export default nextConfig;
