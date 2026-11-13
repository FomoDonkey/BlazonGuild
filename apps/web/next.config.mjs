/** @type {import('next').NextConfig} */
const API = process.env.API_INTERNAL_URL ?? 'http://127.0.0.1:3001';

const securityHeaders = [
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
];

const nextConfig = {
  transpilePackages: ['@blazonguild/types'],
  poweredByHeader: false,
  devIndicators: false,
  images: {
    remotePatterns: [{ protocol: 'https', hostname: 'render.worldofwarcraft.com', pathname: '/**' }],
    formats: ['image/avif', 'image/webp'],
  },
  async rewrites() {
    // Same-origin API: session cookies stay first-party and CSRF checks stay simple.
    return [{ source: '/api/:path*', destination: `${API}/:path*` }];
  },
  async headers() {
    return [{ source: '/:path*', headers: securityHeaders }];
  },
};

export default nextConfig;
