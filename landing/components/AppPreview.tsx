"use client";

import Image from "next/image";

/* ── sparkle dust particle system ──────────────────────────────── */

type AnimKind = "twinkle" | "drift" | "pulse";

interface Dust {
  top?: string;
  bottom?: string;
  left?: string;
  right?: string;
  size: number;
  color: string;
  delay: number;
  duration: number;
  drift: number;
  driftX?: number;
  glow?: boolean; // soft blur glow
  kind: AnimKind;
  shape: "star" | "dot";
}

// Helper to generate scattered particles
function ring(
  count: number,
  opts: {
    region: "left" | "right" | "top" | "bottom" | "inner-left" | "inner-right";
    colors: string[];
    sizeRange: [number, number];
  }
): Dust[] {
  const particles: Dust[] = [];
  const kinds: AnimKind[] = ["twinkle", "drift", "pulse"];

  for (let i = 0; i < count; i++) {
    const t = i / count;
    const color = opts.colors[i % opts.colors.length];
    const size = opts.sizeRange[0] + Math.round((opts.sizeRange[1] - opts.sizeRange[0]) * ((i * 7 + 3) % count) / count);
    const kind = kinds[i % kinds.length];
    const shape: "star" | "dot" = i % 3 === 0 ? "star" : "dot";
    const delay = ((i * 1.7 + 0.3) % 5);
    const duration = 2.5 + (i % 4) * 0.8;
    const drift = 4 + (i % 5) * 2;
    const driftX = kind === "drift" ? 3 + (i % 4) * 2 : undefined;
    const glow = i % 4 === 0;

    const pct = `${5 + Math.round(t * 90)}%`;

    const p: Dust = { size, color, delay, duration, drift, driftX, glow, kind, shape };

    switch (opts.region) {
      case "left":
        p.top = pct;
        p.left = `${2 + (i % 5) * 1.5}%`;
        break;
      case "right":
        p.top = pct;
        p.right = `${2 + (i % 5) * 1.5}%`;
        break;
      case "top":
        p.top = `${2 + (i % 4) * 2}%`;
        p.left = `${15 + Math.round(t * 70)}%`;
        break;
      case "bottom":
        p.bottom = `${2 + (i % 4) * 2}%`;
        p.left = `${15 + Math.round(t * 70)}%`;
        break;
      case "inner-left":
        p.top = pct;
        p.left = `${10 + (i % 6) * 2}%`;
        break;
      case "inner-right":
        p.top = pct;
        p.right = `${10 + (i % 6) * 2}%`;
        break;
    }

    particles.push(p);
  }

  return particles;
}

const colors = ["var(--sj-gold)", "var(--sj-coral)", "var(--sj-highlight)"];
const dustParticles: Dust[] = [
  // Dense edges
  ...ring(8, { region: "left", colors, sizeRange: [3, 8] }),
  ...ring(8, { region: "right", colors, sizeRange: [3, 8] }),
  // Top and bottom scatter
  ...ring(6, { region: "top", colors, sizeRange: [2, 6] }),
  ...ring(6, { region: "bottom", colors, sizeRange: [2, 6] }),
  // Inner glow particles near the image
  ...ring(5, { region: "inner-left", colors, sizeRange: [2, 5] }),
  ...ring(5, { region: "inner-right", colors, sizeRange: [2, 5] }),
  // A few larger accent stars
  { top: "15%", left: "6%", size: 12, color: "var(--sj-gold)", delay: 0, duration: 4, drift: 10, kind: "twinkle", shape: "star", glow: true },
  { top: "40%", right: "4%", size: 14, color: "var(--sj-coral)", delay: 1.5, duration: 4.5, drift: 12, kind: "twinkle", shape: "star", glow: true },
  { bottom: "20%", left: "5%", size: 11, color: "var(--sj-highlight)", delay: 2.8, duration: 5, drift: 8, kind: "twinkle", shape: "star", glow: true },
  { top: "70%", right: "7%", size: 13, color: "var(--sj-gold)", delay: 0.8, duration: 3.5, drift: 14, kind: "twinkle", shape: "star", glow: true },
];

/* ── SVG shapes ────────────────────────────────────────────────── */

function FourPointStar({ size, color }: { size: number; color: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <path d="M12 0C12.5 7 17 11.5 24 12C17 12.5 12.5 17 12 24C11.5 17 7 12.5 0 12C7 11.5 11.5 7 12 0Z" />
    </svg>
  );
}

function DustDot({ size, color }: { size: number; color: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 10 10">
      <circle cx="5" cy="5" r="5" fill={color} />
    </svg>
  );
}

/* ── component ─────────────────────────────────────────────────── */

export function AppPreview() {
  return (
    <>
      {/*
        Desktop: true fixed parallax window.
        The image is position:fixed to the viewport — it NEVER moves.
        This div is just a transparent spacer in the document flow that
        creates the "window" where the fixed image shows through.
      */}
      <div className="relative hidden sm:block" style={{ height: "100vh" }}>
        {/* Fixed layer — locked to viewport, behind everything */}
        <div
          className="fixed inset-0 z-0 flex items-center justify-center overflow-hidden"
          style={{
            background: "linear-gradient(135deg, #16110D 0%, #211913 100%)",
          }}
        >
          {/* Magic sparkle dust */}
          <div className="pointer-events-none absolute inset-0">
            {dustParticles.map((d, i) => {
              const animName =
                d.kind === "twinkle" ? "dust-twinkle" :
                d.kind === "drift" ? "dust-drift" : "dust-pulse";

              return (
                <div
                  key={i}
                  className="absolute"
                  style={{
                    top: d.top,
                    bottom: d.bottom,
                    left: d.left,
                    right: d.right,
                    animation: `${animName} ${d.duration}s ease-in-out ${d.delay}s infinite`,
                    ["--dust-drift" as string]: `${d.drift}px`,
                    ...(d.driftX ? { ["--dust-x" as string]: `${d.driftX}px` } : {}),
                    ...(d.glow ? { filter: `drop-shadow(0 0 ${Math.max(d.size, 4)}px ${d.color})` } : {}),
                  }}
                >
                  {d.shape === "star" ? (
                    <FourPointStar size={d.size} color={d.color} />
                  ) : (
                    <DustDot size={d.size} color={d.color} />
                  )}
                </div>
              );
            })}
          </div>

          {/* App showcase image — scales up with the viewport */}
          <div className="mx-auto w-full max-w-3xl px-6 lg:max-w-5xl lg:px-8 xl:max-w-6xl 2xl:max-w-7xl">
            <Image
              src="/images/app-showcase.png"
              alt="StoryFox app — creation view with story library, floating in a magical storybook scene"
              width={1536}
              height={1024}
              className="w-full h-auto rounded-2xl"
              priority={false}
            />
          </div>
        </div>
      </div>

      {/* Mobile: simple dark section, no fixed positioning */}
      <section
        className="relative py-8 sm:hidden"
        style={{
          background: "linear-gradient(135deg, #16110D 0%, #211913 100%)",
        }}
      >
        <div className="mx-auto max-w-5xl px-4">
          <Image
            src="/images/app-showcase.png"
            alt="StoryFox app — creation view with story library, floating in a magical storybook scene"
            width={1536}
            height={1024}
            className="w-full h-auto rounded-xl"
            priority={false}
          />
        </div>
      </section>
    </>
  );
}
