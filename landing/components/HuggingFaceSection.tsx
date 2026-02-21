"use client";

import Image from "next/image";
import { motion } from "framer-motion";
import { track } from "@vercel/analytics";
import {
  fadeUpVariants,
  staggerContainer,
} from "@/lib/motion";

interface Benefit {
  image: string;
  title: string;
  description: string;
  color: string;
}

const benefits: Benefit[] = [
  {
    image: "/images/hf-better-stories.png",
    title: "Better Stories",
    description:
      "Models like OpenAI GPT-OSS write longer, more coherent stories with varied vocabulary.",
    color: "var(--sj-gold)",
  },
  {
    image: "/images/hf-sharper-illustrations.png",
    title: "Sharper Illustrations",
    description:
      "FLUX.1 from Black Forest Labs produces sharper details, better lighting, and more consistent characters.",
    color: "var(--sj-coral)",
  },
  {
    image: "/images/hf-free.png",
    title: "Completely Free",
    description:
      "Hugging Face\u2019s free tier covers plenty of storybooks. No subscriptions, no hidden costs.",
    color: "var(--sj-mint)",
  },
  {
    image: "/images/hf-secure.png",
    title: "Secure Connection",
    description:
      "Login happens through a secure sign-in window. StoryFox only gets permission to generate.",
    color: "var(--sj-lavender)",
  },
];

const upgradeSteps = [
  {
    number: "1",
    title: "Create a free account",
    description: "Sign up at huggingface.co.",
  },
  {
    number: "2",
    title: "Sign in from the app",
    description: "Open settings, tap \u201cSign in with Hugging Face.\u201d",
  },
  {
    number: "3",
    title: "Pick your models",
    description: "Choose cloud models for text and images.",
  },
];

function HFLogo({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 120 120"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M37.2 36.8c-3.6 0-6.6 2.4-7.8 5.4-.6-.6-1.2-.6-2.4-.6-3 0-5.4 2.4-5.4 5.4 0 .6 0 1.2.6 1.8-2.4 1.2-4.2 3.6-4.2 6.6 0 3 1.8 5.4 4.2 6.6-.6.6-.6 1.2-.6 1.8 0 3 2.4 5.4 5.4 5.4.6 0 1.8 0 2.4-.6 1.2 3 4.2 5.4 7.8 5.4 3 0 5.4-1.8 7.2-4.2 1.8 2.4 4.2 4.2 7.2 4.2 3.6 0 6.6-2.4 7.8-5.4.6.6 1.2.6 2.4.6 3 0 5.4-2.4 5.4-5.4 0-.6 0-1.2-.6-1.8 2.4-1.2 4.2-3.6 4.2-6.6 0-3-1.8-5.4-4.2-6.6.6-.6.6-1.2.6-1.8 0-3-2.4-5.4-5.4-5.4-.6 0-1.8 0-2.4.6-1.2-3-4.2-5.4-7.8-5.4-3 0-5.4 1.8-7.2 4.2-1.8-2.4-4.2-4.2-7.2-4.2z"
        fill="#FFD21E"
      />
      <path
        d="M39.6 52.4c0-2.4-1.8-4.2-4.2-4.2s-4.2 1.8-4.2 4.2c0 1.8 1.2 3.6 3 4.2v6c0 .6.6 1.2 1.2 1.2s1.2-.6 1.2-1.2v-6c1.8-.6 3-2.4 3-4.2zm-4.2-1.8c1.2 0 1.8.6 1.8 1.8s-.6 1.8-1.8 1.8-1.8-.6-1.8-1.8.6-1.8 1.8-1.8zm18 1.8c0-2.4-1.8-4.2-4.2-4.2s-4.2 1.8-4.2 4.2c0 1.8 1.2 3.6 3 4.2v6c0 .6.6 1.2 1.2 1.2s1.2-.6 1.2-1.2v-6c1.8-.6 3-2.4 3-4.2zm-4.2-1.8c1.2 0 1.8.6 1.8 1.8s-.6 1.8-1.8 1.8-1.8-.6-1.8-1.8.6-1.8 1.8-1.8z"
        fill="#4B2F00"
      />
      <path
        d="M44.4 62c-1.2 0-3 .6-4.2 1.8-1.2-1.2-3-1.8-4.2-1.8-.6 0-1.2.6-1.2 1.2s.6 1.2 1.2 1.2c1.2 0 2.4.6 3 1.8.6.6 1.2.6 1.8.6h.6c.6-.6.6-.6.6-1.2.6-1.2 1.8-1.8 3-1.8.6 0 1.2-.6 1.2-1.2-.6 0-1.2-.6-1.8-.6z"
        fill="#4B2F00"
      />
    </svg>
  );
}

export function HuggingFaceSection() {
  return (
    <section id="huggingface" className="relative py-20 sm:py-28">
      <div className="glow-amber pointer-events-none absolute -right-32 top-1/3 hidden h-[500px] w-[500px] sm:block" />

      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Single rounded container */}
        <motion.div
          className="overflow-hidden rounded-3xl border border-sj-border/25"
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.1 }}
          variants={staggerContainer}
        >
          {/* Banner image — full bleed at top */}
          <motion.div variants={fadeUpVariants}>
            <Image
              src="/images/hf-upgrade-banner.png"
              alt="The StoryFox fox and Hugging Face mascot sharing a glowing storybook at a cozy candlelit desk"
              width={1536}
              height={1024}
              className="h-36 w-full object-cover sm:h-52 md:h-64"
            />
          </motion.div>

          {/* Header + benefit cards */}
          <motion.div
            className="p-4 sm:p-8 md:p-10"
            style={{
              background: `linear-gradient(135deg, color-mix(in srgb, var(--sj-coral) 5%, transparent), color-mix(in srgb, var(--sj-gold) 4%, transparent))`,
            }}
            variants={fadeUpVariants}
          >
            {/* Chip + heading + subheading */}
            <div className="mb-8 text-center">
              <div className="mb-4 inline-flex items-center rounded-full border border-sj-highlight/40 bg-sj-highlight/10 px-4 py-1.5">
                <span className="font-sans text-sm font-semibold text-sj-gold">
                  Free Upgrade
                </span>
              </div>
              <h2 className="section-title mb-3 font-serif font-bold text-sj-text">
                Go Further with Hugging Face
              </h2>
              <p className="mx-auto max-w-2xl text-lg leading-relaxed text-sj-secondary">
                StoryFox works on its own with your Mac&apos;s built-in AI. Connect
                a free Hugging Face account to unlock better stories and sharper
                illustrations from open models like OpenAI GPT-OSS and FLUX.1.
              </p>
            </div>

            {/* 4 benefit cards — desktop: 4-col grid */}
            <div className="hidden gap-4 lg:grid lg:grid-cols-4">
              {benefits.map((benefit) => (
                <div
                  key={benefit.title}
                  className="flex flex-col items-center rounded-2xl border p-4 text-center"
                  style={{
                    borderColor: `color-mix(in srgb, ${benefit.color} 20%, transparent)`,
                    background: `color-mix(in srgb, ${benefit.color} 4%, transparent)`,
                  }}
                >
                  <div
                    className="mb-3 overflow-hidden rounded-xl"
                    style={{
                      boxShadow: `0 4px 16px color-mix(in srgb, ${benefit.color} 15%, transparent)`,
                    }}
                  >
                    <Image
                      src={benefit.image}
                      alt={benefit.title}
                      width={100}
                      height={100}
                      className="h-[100px] w-[100px] object-cover"
                    />
                  </div>
                  <h4 className="mb-1 font-sans text-sm font-semibold text-sj-text">
                    {benefit.title}
                  </h4>
                  <p className="text-xs leading-relaxed text-sj-secondary">
                    {benefit.description}
                  </p>
                </div>
              ))}
            </div>

            {/* 4 benefit cards — mobile/tablet: full-width image-topped cards */}
            <div className="flex flex-col gap-4 lg:hidden">
              {benefits.map((benefit) => (
                <div
                  key={benefit.title}
                  className="overflow-hidden rounded-2xl border"
                  style={{
                    borderColor: `color-mix(in srgb, ${benefit.color} 20%, transparent)`,
                    background: `color-mix(in srgb, ${benefit.color} 4%, transparent)`,
                  }}
                >
                  <div className="flex items-center gap-4 p-4">
                    <div
                      className="shrink-0 overflow-hidden rounded-xl"
                      style={{
                        boxShadow: `0 4px 12px color-mix(in srgb, ${benefit.color} 12%, transparent)`,
                      }}
                    >
                      <Image
                        src={benefit.image}
                        alt={benefit.title}
                        width={72}
                        height={72}
                        className="h-[72px] w-[72px] object-cover"
                      />
                    </div>
                    <div>
                      <h4 className="mb-0.5 font-sans text-sm font-semibold text-sj-text">
                        {benefit.title}
                      </h4>
                      <p className="text-xs leading-relaxed text-sj-secondary">
                        {benefit.description}
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </motion.div>

          {/* Divider */}
          <div className="h-px bg-sj-border/20" />

          {/* Bottom: Get started steps + CTA */}
          <motion.div
            className="bg-[var(--sj-card)]/40 p-4 sm:p-8 md:p-10"
            variants={fadeUpVariants}
          >
            <h3 className="mb-8 text-center font-serif text-xl font-semibold text-sj-text">
              Get started in 3 steps
            </h3>

            {/* Desktop: horizontal steps with circles */}
            <div className="mx-auto hidden max-w-4xl grid-cols-3 gap-6 sm:grid">
              {upgradeSteps.map((step) => (
                <div key={step.number} className="flex flex-col items-center text-center">
                  <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-sj-coral font-serif text-sm font-bold text-white">
                    {step.number}
                  </div>
                  <div className="mt-2">
                    <h4 className="mb-0.5 font-sans text-sm font-semibold text-sj-text">
                      {step.title}
                    </h4>
                    <p className="text-xs leading-relaxed text-sj-secondary">
                      {step.description}
                    </p>
                  </div>
                </div>
              ))}
            </div>

            {/* Mobile: accent-bordered step cards */}
            <div className="flex flex-col gap-3 sm:hidden">
              {upgradeSteps.map((step) => (
                <div
                  key={step.number}
                  className="flex items-center gap-3 rounded-xl border-l-[3px] border-sj-coral bg-[var(--sj-card)]/30 px-4 py-3"
                >
                  <span className="font-serif text-lg font-bold text-sj-coral">
                    {step.number}.
                  </span>
                  <div>
                    <h4 className="font-sans text-sm font-semibold text-sj-text">
                      {step.title}
                    </h4>
                    <p className="text-xs leading-relaxed text-sj-secondary">
                      {step.description}
                    </p>
                  </div>
                </div>
              ))}
            </div>

            {/* CTA */}
            <div className="mt-8 flex flex-col items-center gap-3">
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
                Completely free. No credit card required.
              </p>
            </div>
          </motion.div>
        </motion.div>

        {/* Bottom note */}
        <motion.p
          className="mt-10 text-center text-sm text-sj-muted"
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true }}
          variants={fadeUpVariants}
        >
          Already have a Hugging Face account? Just open StoryFox settings and
          sign in. Your existing account works.
        </motion.p>
      </div>
    </section>
  );
}
