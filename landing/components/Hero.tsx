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

export function Hero() {
  return (
    <section className="relative min-h-screen overflow-hidden pt-24 pb-16 sm:pt-32 sm:pb-24">
      {/* Ambient glow effects */}
      <div className="glow-amber pointer-events-none absolute -right-32 -top-32 h-[500px] w-[500px]" />
      <div className="glow-peach pointer-events-none absolute -bottom-24 -left-24 h-[400px] w-[400px]" />

      <div className="mx-auto flex max-w-7xl flex-col items-center gap-12 px-4 sm:px-6 md:flex-row md:items-center md:gap-16 lg:px-8">
        {/* Text column */}
        <motion.div
          className="flex flex-1 flex-col items-center text-center md:items-start md:text-left"
          variants={staggerContainer}
          initial="hidden"
          animate="visible"
        >
          <motion.div variants={scaleInVariants} className="mb-6">
            <Image
              src="/app-icon.png"
              alt="StoryJuicer"
              width={80}
              height={80}
              priority
              className="rounded-2xl shadow-[0_8px_24px_rgba(0,0,0,0.12)]"
            />
          </motion.div>

          <motion.h1
            variants={fadeUpVariants}
            className="hero-title mb-4 font-serif font-bold text-sj-coral"
          >
            StoryJuicer
          </motion.h1>

          <motion.p
            variants={fadeUpVariants}
            className="mb-4 max-w-lg font-serif text-xl leading-relaxed text-sj-text sm:text-2xl"
          >
            AI-powered illustrated children&apos;s storybooks — on your device.
          </motion.p>

          <motion.p
            variants={fadeUpVariants}
            className="mb-8 max-w-md text-base leading-relaxed text-sj-secondary sm:text-lg"
          >
            Type a story idea, pick a style, and get a fully illustrated book
            with text, cover art, and print-ready PDF export — all in minutes.
          </motion.p>

          <motion.div variants={fadeUpVariants}>
            <DownloadButton />
          </motion.div>

          <motion.div
            variants={fadeUpVariants}
            className="mt-6 flex flex-wrap items-center justify-center gap-2 md:justify-start"
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
        </motion.div>

        {/* Illustration showcase — fanned storybook pages */}
        <motion.div
          className="relative hidden flex-1 md:flex md:items-center md:justify-center"
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.7, delay: 0.2, ease: "easeOut" }}
        >
          <div className="relative h-[480px] w-[420px]">
            {/* Back card — sketch style */}
            <motion.div
              className="absolute left-0 top-8 h-[340px] w-[260px] overflow-hidden rounded-2xl shadow-[0_12px_40px_rgba(0,0,0,0.15)]"
              initial={{ opacity: 0, rotate: -8, x: -20 }}
              animate={{ opacity: 1, rotate: -8, x: 0 }}
              transition={{ duration: 0.6, delay: 0.4 }}
            >
              <Image
                src="/images/style-sketch.png"
                alt="Sketch style storybook illustration"
                fill
                className="object-cover"
                sizes="260px"
              />
              <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/50 to-transparent p-4">
                <span className="font-sans text-xs font-semibold text-white/90">
                  Sketch Style
                </span>
              </div>
            </motion.div>

            {/* Middle card — animation style */}
            <motion.div
              className="absolute right-4 top-0 h-[340px] w-[260px] overflow-hidden rounded-2xl shadow-[0_16px_48px_rgba(0,0,0,0.18)]"
              initial={{ opacity: 0, rotate: 4, x: 20 }}
              animate={{ opacity: 1, rotate: 4, x: 0 }}
              transition={{ duration: 0.6, delay: 0.55 }}
            >
              <Image
                src="/images/style-animation.png"
                alt="Animation style storybook illustration"
                fill
                className="object-cover"
                sizes="260px"
              />
              <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/50 to-transparent p-4">
                <span className="font-sans text-xs font-semibold text-white/90">
                  Animation Style
                </span>
              </div>
            </motion.div>

            {/* Front card — illustration style (hero) */}
            <motion.div
              className="absolute bottom-0 left-1/2 h-[360px] w-[280px] -translate-x-1/2 overflow-hidden rounded-2xl shadow-[0_20px_60px_rgba(0,0,0,0.22)] ring-1 ring-white/20"
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.7 }}
            >
              <Image
                src="/images/style-illustration.png"
                alt="Classic illustration style storybook"
                fill
                className="object-cover"
                sizes="280px"
                priority
              />
              <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/60 via-black/30 to-transparent p-5">
                <p className="font-serif text-sm font-semibold leading-snug text-white">
                  &ldquo;A curious fox reading under a glowing oak tree&rdquo;
                </p>
                <span className="mt-1 inline-block font-sans text-xs text-white/70">
                  Illustration Style
                </span>
              </div>
            </motion.div>

            {/* Floating sparkle accents */}
            <FloatingElement
              className="absolute -left-4 bottom-24"
              delay={0}
              duration={5}
            >
              <div className="flex h-8 w-8 items-center justify-center rounded-full bg-sj-highlight/25 text-sm backdrop-blur-sm">
                ✨
              </div>
            </FloatingElement>

            <FloatingElement
              className="absolute -right-2 top-16"
              delay={1.5}
              duration={4.5}
            >
              <div className="flex h-8 w-8 items-center justify-center rounded-full bg-sj-coral/15 text-sm backdrop-blur-sm">
                🎨
              </div>
            </FloatingElement>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
