"use client";

import { motion } from "framer-motion";
import { track } from "@vercel/analytics";
import { fadeUpVariants, staggerContainer } from "@/lib/motion";
import { GlassCard } from "./GlassCard";

const upgradeSteps = [
  {
    number: "1",
    title: "Create a free account",
    description:
      "Sign up at huggingface.co — takes less than a minute.",
  },
  {
    number: "2",
    title: "Sign in from the app",
    description:
      'Open StoryJuicer settings and tap "Sign in with Hugging Face." One click, done.',
  },
  {
    number: "3",
    title: "Pick your models",
    description:
      "Choose from powerful cloud models for both text and illustrations. The app handles the rest.",
  },
];

const benefits = [
  {
    icon: "📝",
    title: "Smarter Stories",
    description:
      "Access models like Llama 4 for richer, more creative storylines with better vocabulary and plot structure.",
  },
  {
    icon: "🖼️",
    title: "Stunning Illustrations",
    description:
      "Generate images with FLUX.1 from Black Forest Labs — dramatically more detailed and vibrant than on-device.",
  },
  {
    icon: "💰",
    title: "Completely Free",
    description:
      "Hugging Face's free tier includes generous inference limits — no subscriptions, no hidden costs.",
  },
  {
    icon: "🔐",
    title: "Secure Connection",
    description:
      "Your login is handled through a secure sign-in window. StoryJuicer only gets permission to generate — nothing else.",
  },
];

function HFLogo({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M37.2 36.8c-3.6 0-6.6 2.4-7.8 5.4-.6-.6-1.2-.6-2.4-.6-3 0-5.4 2.4-5.4 5.4 0 .6 0 1.2.6 1.8-2.4 1.2-4.2 3.6-4.2 6.6 0 3 1.8 5.4 4.2 6.6-.6.6-.6 1.2-.6 1.8 0 3 2.4 5.4 5.4 5.4.6 0 1.8 0 2.4-.6 1.2 3 4.2 5.4 7.8 5.4 3 0 5.4-1.8 7.2-4.2 1.8 2.4 4.2 4.2 7.2 4.2 3.6 0 6.6-2.4 7.8-5.4.6.6 1.2.6 2.4.6 3 0 5.4-2.4 5.4-5.4 0-.6 0-1.2-.6-1.8 2.4-1.2 4.2-3.6 4.2-6.6 0-3-1.8-5.4-4.2-6.6.6-.6.6-1.2.6-1.8 0-3-2.4-5.4-5.4-5.4-.6 0-1.8 0-2.4.6-1.2-3-4.2-5.4-7.8-5.4-3 0-5.4 1.8-7.2 4.2-1.8-2.4-4.2-4.2-7.2-4.2z" fill="#FFD21E"/>
      <path d="M39.6 52.4c0-2.4-1.8-4.2-4.2-4.2s-4.2 1.8-4.2 4.2c0 1.8 1.2 3.6 3 4.2v6c0 .6.6 1.2 1.2 1.2s1.2-.6 1.2-1.2v-6c1.8-.6 3-2.4 3-4.2zm-4.2-1.8c1.2 0 1.8.6 1.8 1.8s-.6 1.8-1.8 1.8-1.8-.6-1.8-1.8.6-1.8 1.8-1.8zm18 1.8c0-2.4-1.8-4.2-4.2-4.2s-4.2 1.8-4.2 4.2c0 1.8 1.2 3.6 3 4.2v6c0 .6.6 1.2 1.2 1.2s1.2-.6 1.2-1.2v-6c1.8-.6 3-2.4 3-4.2zm-4.2-1.8c1.2 0 1.8.6 1.8 1.8s-.6 1.8-1.8 1.8-1.8-.6-1.8-1.8.6-1.8 1.8-1.8z" fill="#4B2F00"/>
      <path d="M44.4 62c-1.2 0-3 .6-4.2 1.8-1.2-1.2-3-1.8-4.2-1.8-.6 0-1.2.6-1.2 1.2s.6 1.2 1.2 1.2c1.2 0 2.4.6 3 1.8.6.6 1.2.6 1.8.6h.6c.6-.6.6-.6.6-1.2.6-1.2 1.8-1.8 3-1.8.6 0 1.2-.6 1.2-1.2-.6 0-1.2-.6-1.8-.6z" fill="#4B2F00"/>
    </svg>
  );
}

export function HuggingFaceSection() {
  return (
    <section id="huggingface" className="relative py-20 sm:py-28">
      <div className="glow-amber pointer-events-none absolute -right-32 top-1/3 h-[500px] w-[500px]" />

      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <motion.div
          className="mb-16 text-center"
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.3 }}
          variants={fadeUpVariants}
        >
          <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-sj-highlight/40 bg-sj-highlight/10 px-4 py-1.5">
            <HFLogo className="h-5 w-5" />
            <span className="font-sans text-sm font-semibold text-sj-gold">
              Free Upgrade
            </span>
          </div>
          <h2 className="section-title mb-4 font-serif font-bold text-sj-text">
            Supercharge with Hugging Face
          </h2>
          <p className="mx-auto max-w-2xl text-lg leading-relaxed text-sj-secondary">
            StoryJuicer works great right out of the box with your Mac&apos;s built-in AI.
            But connect a free Hugging Face account and unlock <strong className="text-sj-text">dramatically better</strong> stories
            and illustrations powered by the world&apos;s best open AI models.
          </p>
        </motion.div>

        {/* Two-column: benefits + how to connect */}
        <div className="grid grid-cols-1 gap-12 lg:grid-cols-2">
          {/* Benefits */}
          <motion.div
            className="grid grid-cols-1 gap-5 sm:grid-cols-2"
            variants={staggerContainer}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, amount: 0.15 }}
          >
            {benefits.map((benefit) => (
              <motion.div key={benefit.title} variants={fadeUpVariants}>
                <GlassCard className="flex h-full flex-col p-5" hover>
                  <div className="mb-3 text-2xl">{benefit.icon}</div>
                  <h3 className="mb-1.5 font-serif text-base font-semibold text-sj-text">
                    {benefit.title}
                  </h3>
                  <p className="text-sm leading-relaxed text-sj-secondary">
                    {benefit.description}
                  </p>
                </GlassCard>
              </motion.div>
            ))}
          </motion.div>

          {/* How to connect */}
          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, amount: 0.15 }}
            variants={fadeUpVariants}
          >
            <GlassCard className="h-full p-8">
              <h3 className="mb-6 font-serif text-xl font-semibold text-sj-text">
                Get started in 3 steps
              </h3>

              <div className="flex flex-col gap-6">
                {upgradeSteps.map((step, i) => (
                  <div key={step.number} className="flex gap-4">
                    <div className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full bg-sj-coral font-serif text-sm font-bold text-white">
                      {step.number}
                    </div>
                    <div>
                      <h4 className="mb-1 font-sans text-base font-semibold text-sj-text">
                        {step.title}
                      </h4>
                      <p className="text-sm leading-relaxed text-sj-secondary">
                        {step.description}
                      </p>
                    </div>
                  </div>
                ))}
              </div>

              <div className="mt-8 h-px bg-gradient-to-r from-transparent via-sj-border to-transparent" />

              <div className="mt-6 flex flex-col items-start gap-3">
                <a
                  href="https://huggingface.co/join"
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={() => track("HuggingFace Join")}
                  className="inline-flex items-center gap-2.5 rounded-full bg-sj-coral px-6 py-3 font-sans text-sm font-semibold text-white shadow-[0_4px_14px_rgba(180,84,58,0.3)] transition-all duration-200 hover:bg-sj-coral-hover hover:shadow-[0_6px_20px_rgba(180,84,58,0.45)]"
                >
                  <HFLogo className="h-4 w-4" />
                  Create a Free Account
                </a>
                <p className="text-xs text-sj-muted">
                  Completely free — no credit card required.
                </p>
              </div>
            </GlassCard>
          </motion.div>
        </div>

        {/* Bottom note */}
        <motion.p
          className="mt-10 text-center text-sm text-sj-muted"
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true }}
          variants={fadeUpVariants}
        >
          Already have a Hugging Face account? Just open StoryJuicer settings and sign in — your existing account works perfectly.
        </motion.p>
      </div>
    </section>
  );
}
