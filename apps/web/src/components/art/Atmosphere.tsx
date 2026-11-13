'use client';

import { useEffect, useRef } from 'react';
import { cn } from '@/lib/utils';

/**
 * Rising embers drawn on a canvas. Pauses off-screen and is disabled when the user
 * prefers reduced motion. Purely decorative (aria-hidden).
 */
export function Embers({ className, density = 70, hue = 28 }: { className?: string; density?: number; hue?: number }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    let w = 0, h = 0, raf = 0, visible = true;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const resize = () => {
      w = canvas.clientWidth;
      h = canvas.clientHeight;
      canvas.width = w * dpr;
      canvas.height = h * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    const mk = (y?: number) => ({ x: Math.random() * w, y: y ?? h + Math.random() * h * 0.3, r: 0.6 + Math.random() * 2.2, v: 0.25 + Math.random() * 0.9, a: Math.random() * Math.PI * 2, life: 0.4 + Math.random() * 0.6 });
    const ps = Array.from({ length: density }, () => mk(Math.random() * h));
    const tick = () => {
      if (!visible) return;
      ctx.clearRect(0, 0, w, h);
      ctx.globalCompositeOperation = 'lighter';
      for (const p of ps) {
        p.y -= p.v;
        p.a += 0.02;
        p.x += Math.sin(p.a) * 0.35;
        const fade = Math.max(0, Math.min(1, p.y / h)) * p.life;
        if (p.y < -10) Object.assign(p, mk());
        const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.r * 4);
        g.addColorStop(0, `hsla(${hue + 18}, 100%, 75%, ${fade})`);
        g.addColorStop(0.4, `hsla(${hue}, 100%, 55%, ${fade * 0.55})`);
        g.addColorStop(1, `hsla(${hue - 10}, 100%, 40%, 0)`);
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r * 4, 0, Math.PI * 2);
        ctx.fill();
      }
      raf = requestAnimationFrame(tick);
    };
    const io = new IntersectionObserver(([e]) => {
      visible = e.isIntersecting;
      if (visible) raf = requestAnimationFrame(tick);
      else cancelAnimationFrame(raf);
    });
    io.observe(canvas);
    window.addEventListener('resize', resize);
    raf = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(raf);
      io.disconnect();
      window.removeEventListener('resize', resize);
    };
  }, [density, hue]);
  return <canvas ref={ref} aria-hidden className={cn('pointer-events-none absolute inset-0 h-full w-full', className)} />;
}

/** Mouse parallax: children with data-depth move proportionally to the pointer. */
export function Parallax({ children, className, strength = 18 }: { children: React.ReactNode; className?: string; strength?: number }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el || window.matchMedia('(prefers-reduced-motion: reduce)').matches || window.matchMedia('(pointer: coarse)').matches) return;
    let raf = 0;
    const onMove = (e: PointerEvent) => {
      const r = el.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        el.querySelectorAll<HTMLElement>('[data-depth]').forEach((n) => {
          const d = Number(n.dataset.depth);
          n.style.transform = `translate3d(${-x * strength * d}px, ${-y * strength * d * 0.6}px, 0)`;
        });
      });
    };
    el.addEventListener('pointermove', onMove);
    return () => el.removeEventListener('pointermove', onMove);
  }, [strength]);
  return (
    <div ref={ref} className={className}>
      {children}
    </div>
  );
}
