"use client";

import { motion } from "framer-motion";
import { fadeUpVariants, staggerContainer } from "@/lib/motion";
import { GlassCard } from "./GlassCard";

const steps = [
  {
    number: 1,
    title: "Describe",
    description:
      '"A curious fox building a moonlight library in the forest"',
    icon: "💭",
    color: "var(--sj-coral)",
  },
  {
    number: 2,
    title: "Customize",
    description: "Pick page count, book format, and illustration style",
    icon: "🎛️",
    color: "var(--sj-gold)",
  },
  {
    number: 3,
    title: "Generate",
    description: "Text streams live, then illustrations paint concurrently",
    icon: "⚡",
    color: "var(--sj-mint)",
  },
  {
    number: 4,
    title: "Export",
    description: "Flip through pages, then save as 300 DPI print-ready PDF",
    icon: "📄",
    color: "var(--sj-sky)",
  },
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="relative py-20 sm:py-28">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <motion.div
          className="mb-16 text-center"
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.3 }}
          variants={fadeUpVariants}
        >
          <h2 className="section-title mb-4 font-serif font-bold text-sj-text">
            How It Works
          </h2>
          <p className="mx-auto max-w-xl text-lg text-sj-secondary">
            From idea to illustrated storybook in four simple steps.
          </p>
        </motion.div>

        <motion.div
          className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4"
          variants={staggerContainer}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.15 }}
        >
          {steps.map((step) => (
            <motion.div key={step.number} variants={fadeUpVariants}>
              <GlassCard className="flex h-full flex-col p-6" hover>
                {/* Step number badge */}
                <div
                  className="mb-4 flex h-10 w-10 items-center justify-center rounded-full font-serif text-lg font-bold text-white"
                  style={{ backgroundColor: step.color }}
                >
                  {step.number}
                </div>

                {/* Icon */}
                <div className="mb-3 text-3xl">{step.icon}</div>

                {/* Title */}
                <h3 className="mb-2 font-serif text-xl font-semibold text-sj-text">
                  {step.title}
                </h3>

                {/* Description */}
                <p className="text-sm leading-relaxed text-sj-secondary">
                  {step.description}
                </p>
              </GlassCard>
            </motion.div>
          ))}
        </motion.div>

        {/* Connector line (desktop only) */}
        <div className="mt-8 hidden items-center justify-center lg:flex">
          <div className="h-px w-3/4 bg-gradient-to-r from-sj-coral/40 via-sj-gold/40 via-50% to-sj-sky/40" />
        </div>
      </div>
    </section>
  );
}
