"use client";

import { motion } from "framer-motion";
import { scaleInVariants, staggerContainer } from "@/lib/motion";
import { GlassCard } from "./GlassCard";

const features = [
  {
    icon: "🔒",
    title: "Works Offline",
    description:
      "Everything runs on your device by default. No internet needed, no accounts required. Your stories stay private.",
    color: "var(--sj-mint)",
  },
  {
    icon: "🖨️",
    title: "Print-Ready PDF",
    description:
      "Export at 300 DPI with professional book dimensions. Ready to print at home or a print shop.",
    color: "var(--sj-gold)",
  },
  {
    icon: "🎨",
    title: "3 Illustration Styles",
    description:
      "Classic painterly illustration, Pixar-style animation, or hand-drawn pencil sketch.",
    color: "var(--sj-coral)",
  },
  {
    icon: "📐",
    title: "4 Book Formats",
    description:
      'Standard square, landscape, portrait, or small square — up to 11" × 8.5".',
    color: "var(--sj-lavender)",
  },
  {
    icon: "🛡️",
    title: "Safe for Kids",
    description:
      "Built-in safety guardrails ensure every story is age-appropriate for ages 3–8. Peace of mind for parents.",
    color: "var(--sj-mint)",
  },
  {
    icon: "🤗",
    title: "Hugging Face Cloud",
    description:
      "Connect a free Hugging Face account to unlock more powerful AI models for even better stories and illustrations.",
    color: "var(--sj-gold)",
    link: "#huggingface",
  },
  {
    icon: "📱",
    title: "Mac & iPhone",
    description:
      "Available on both macOS and iOS. Make storybooks on your Mac at home or on the go with your iPhone.",
    color: "var(--sj-coral)",
  },
  {
    icon: "📚",
    title: "Save Your Library",
    description:
      "All your storybooks are saved automatically. Come back anytime to re-read, export, or share them.",
    color: "var(--sj-sky)",
  },
];

export function Features() {
  return (
    <section id="features" className="relative py-20 sm:py-28">
      {/* Subtle ambient glow */}
      <div className="glow-peach pointer-events-none absolute right-0 top-1/4 h-[400px] w-[400px]" />

      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <motion.div
          className="mb-16 text-center"
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.3 }}
          variants={scaleInVariants}
        >
          <h2 className="section-title mb-4 font-serif font-bold text-sj-text">
            Everything You Need
          </h2>
          <p className="mx-auto max-w-xl text-lg text-sj-secondary">
            Professional-quality storybooks with powerful features built right
            in.
          </p>
        </motion.div>

        <motion.div
          className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
          variants={staggerContainer}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.1 }}
        >
          {features.map((feature) => {
            const content = (
              <GlassCard className="flex h-full flex-col p-6" hover>
                <div
                  className="mb-4 flex h-11 w-11 items-center justify-center rounded-full text-2xl"
                  style={{
                    backgroundColor: `color-mix(in srgb, ${feature.color} 12%, transparent)`,
                  }}
                >
                  {feature.icon}
                </div>

                <h3 className="mb-2 font-serif text-lg font-semibold text-sj-text">
                  {feature.title}
                </h3>

                <p className="text-sm leading-relaxed text-sj-secondary">
                  {feature.description}
                </p>

                {"link" in feature && (
                  <span className="mt-3 inline-flex items-center gap-1 text-xs font-semibold text-sj-coral">
                    Learn more
                    <svg className="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
                    </svg>
                  </span>
                )}
              </GlassCard>
            );

            return (
              <motion.div key={feature.title} variants={scaleInVariants}>
                {"link" in feature ? (
                  <a href={(feature as { link: string }).link} className="block h-full">
                    {content}
                  </a>
                ) : (
                  content
                )}
              </motion.div>
            );
          })}
        </motion.div>
      </div>
    </section>
  );
}
