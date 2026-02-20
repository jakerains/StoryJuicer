"use client";

import { motion } from "framer-motion";
import Image from "next/image";
import { fadeUpVariants, scaleInVariants, staggerContainer } from "@/lib/motion";
import { DownloadButton } from "./DownloadButton";

function FloatingElement({
  children,
  className,
  delay = 0,
  duration = 4,
}: {
  children: React.ReactNode;
  className?: string;
  delay?: number;
  duration?: number;
}) {
  return (
    <motion.div
      className={className}
      animate={{ y: [-8, 8, -8] }}
      transition={{
        duration,
        repeat: Infinity,
        ease: "easeInOut",
        delay,
      }}
    >
      {children}
    </motion.div>
  );
}

const styleShowcase = [
  { src: "/images/style-illustration.png", label: "Illustration", quote: "A curious fox reading under a glowing oak tree" },
  { src: "/images/style-animation.png", label: "Animation", quote: "A brave little robot exploring a candy planet" },
  { src: "/images/style-sketch.png", label: "Sketch", quote: "A cat sailing a paper boat across a puddle" },
];

export function Hero() {
  return (
    <section className="relative min-h-screen overflow-hidden pt-24 pb-16 sm:pt-32 sm:pb-24">
      {/* Ambient glow effects */}
      <div className="glow-amber pointer-events-none absolute -right-32 -top-32 h-[500px] w-[500px]" />
      <div className="glow-peach pointer-events-none absolute -bottom-24 -left-24 h-[400px] w-[400px]" />
      <div className="pointer-events-none absolute left-1/2 top-32 h-[600px] w-[600px] -translate-x-1/2 rounded-full bg-[var(--sj-highlight)]/10 blur-[120px]" />

      <motion.div
        className="mx-auto flex max-w-4xl flex-col items-center px-4 text-center sm:px-6 lg:px-8"
        variants={staggerContainer}
        initial="hidden"
        animate="visible"
      >
        {/* Hero illustration with floating accents */}
        <motion.div variants={scaleInVariants} className="relative mb-8">
          <Image
            src="/images/storyfox-hero.png"
            alt="StoryFox — a fox curled up with a storybook"
            width={380}
            height={380}
            priority
            className="drop-shadow-[0_16px_48px_rgba(180,84,58,0.25)]"
          />

          {/* Floating sparkle accents around the illustration */}
          <FloatingElement
            className="absolute -left-6 bottom-16"
            delay={0}
            duration={5}
          >
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-[var(--sj-highlight)]/20 text-base backdrop-blur-sm">
              ✨
            </div>
          </FloatingElement>

          <FloatingElement
            className="absolute -right-4 top-12"
            delay={1.5}
            duration={4.5}
          >
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-sj-coral/15 text-base backdrop-blur-sm">
              🎨
            </div>
          </FloatingElement>

          <FloatingElement
            className="absolute -right-8 bottom-24"
            delay={0.8}
            duration={5.5}
          >
            <div className="flex h-7 w-7 items-center justify-center rounded-full bg-[var(--sj-gold)]/20 text-sm backdrop-blur-sm">
              📖
            </div>
          </FloatingElement>
        </motion.div>

        {/* Gradient heading */}
        <motion.h1
          variants={fadeUpVariants}
          className="mb-4 font-serif text-5xl font-bold tracking-tight sm:text-6xl md:text-7xl"
          style={{
            backgroundImage: "linear-gradient(135deg, var(--sj-coral), var(--sj-gold), var(--sj-highlight), var(--sj-coral))",
            backgroundClip: "text",
            WebkitBackgroundClip: "text",
            color: "transparent",
          }}
        >
          StoryFox
        </motion.h1>

        {/* Tagline */}
        <motion.p
          variants={fadeUpVariants}
          className="mb-4 max-w-xl font-serif text-xl leading-relaxed text-sj-text sm:text-2xl"
        >
          AI-powered illustrated children&apos;s storybooks, on your device.
        </motion.p>

        {/* Description */}
        <motion.p
          variants={fadeUpVariants}
          className="mb-10 max-w-lg text-base leading-relaxed text-sj-secondary sm:text-lg"
        >
          Type a story idea, pick a style, and get a fully illustrated book
          with text, cover art, and print-ready PDF export.
        </motion.p>

        {/* CTA */}
        <motion.div variants={fadeUpVariants}>
          <DownloadButton />
        </motion.div>

        {/* Requirement badges */}
        <motion.div
          variants={fadeUpVariants}
          className="mt-5 flex flex-wrap items-center justify-center gap-2"
        >
          {["macOS 26", "Apple Silicon", "Apple Intelligence"].map((req) => (
            <span
              key={req}
              className="rounded-full border border-sj-border/60 bg-[var(--sj-card)]/60 px-3 py-1 font-sans text-xs font-medium text-sj-muted"
            >
              {req}
            </span>
          ))}
        </motion.div>

        {/* Style showcase strip */}
        <motion.div
          variants={fadeUpVariants}
          className="mt-16 w-full max-w-3xl"
        >
          <p className="mb-6 font-sans text-sm font-semibold uppercase tracking-widest text-sj-muted">
            Three illustration styles
          </p>
          <div className="grid grid-cols-3 gap-4">
            {styleShowcase.map((style, i) => (
              <motion.div
                key={style.label}
                className="group relative overflow-hidden rounded-2xl shadow-[0_8px_32px_rgba(0,0,0,0.12)] ring-1 ring-black/5 transition-shadow duration-300 hover:shadow-[0_12px_40px_rgba(0,0,0,0.18)]"
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, delay: 0.8 + i * 0.12 }}
              >
                <div className="relative aspect-[3/4]">
                  <Image
                    src={style.src}
                    alt={`${style.label} style storybook illustration`}
                    fill
                    className="object-cover transition-transform duration-500 group-hover:scale-105"
                    sizes="(max-width: 768px) 33vw, 280px"
                  />
                  <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/60 via-black/25 to-transparent p-4">
                    <p className="font-serif text-xs leading-snug text-white/90 sm:text-sm">
                      &ldquo;{style.quote}&rdquo;
                    </p>
                    <span className="mt-1 inline-block font-sans text-[11px] font-semibold uppercase tracking-wider text-white/70">
                      {style.label}
                    </span>
                  </div>
                </div>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </motion.div>
    </section>
  );
}
