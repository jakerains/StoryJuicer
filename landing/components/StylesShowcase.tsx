"use client";

import { motion } from "framer-motion";
import Image from "next/image";
import { fadeUpVariants, staggerContainer } from "@/lib/motion";
import { GlassCard } from "./GlassCard";

const styles = [
  {
    name: "Illustration",
    tagline: "Classic children's book — painterly brushstrokes and soft shading",
    image: "/images/style-illustration.png",
    fallbackGradient: "from-amber-100 to-green-100 dark:from-amber-900/30 dark:to-green-900/30",
    fallbackIcon: "🖌️",
    accentColor: "var(--sj-coral)",
  },
  {
    name: "Animation",
    tagline: "Pixar-inspired cartoon — rounded shapes and cinematic lighting",
    image: "/images/style-animation.png",
    fallbackGradient: "from-blue-100 to-purple-100 dark:from-blue-900/30 dark:to-purple-900/30",
    fallbackIcon: "🎬",
    accentColor: "var(--sj-sky)",
  },
  {
    name: "Sketch",
    tagline: "Hand-drawn pencil lines with watercolor wash fill",
    image: "/images/style-sketch.png",
    fallbackGradient: "from-orange-100 to-rose-100 dark:from-orange-900/30 dark:to-rose-900/30",
    fallbackIcon: "✏️",
    accentColor: "var(--sj-gold)",
  },
];

function StyleCard({
  style,
}: {
  style: (typeof styles)[0];
}) {
  return (
    <GlassCard className="flex h-full flex-col overflow-hidden" hover>
      {/* Accent bar */}
      <div
        className="h-1"
        style={{ backgroundColor: style.accentColor }}
      />

      {/* Image area */}
      <div className="relative aspect-[4/3] overflow-hidden">
        <Image
          src={style.image}
          alt={`${style.name} style example`}
          fill
          className="object-cover transition-transform duration-300 group-hover:scale-105"
          sizes="(max-width: 768px) 100vw, 33vw"
        />
      </div>

      {/* Text area */}
      <div className="flex flex-1 flex-col p-5">
        <h3 className="mb-2 font-serif text-xl font-semibold text-sj-text">
          {style.name}
        </h3>
        <p className="text-sm leading-relaxed text-sj-secondary">
          {style.tagline}
        </p>
      </div>
    </GlassCard>
  );
}

export function StylesShowcase() {
  return (
    <section id="styles" className="relative py-20 sm:py-28">
      <div className="glow-amber pointer-events-none absolute -left-32 top-0 h-[400px] w-[400px]" />

      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <motion.div
          className="mb-16 text-center"
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.3 }}
          variants={fadeUpVariants}
        >
          <h2 className="section-title mb-4 font-serif font-bold text-sj-text">
            Three Distinct Styles
          </h2>
          <p className="mx-auto max-w-xl text-lg text-sj-secondary">
            Choose the perfect visual style for your story.
          </p>
        </motion.div>

        <motion.div
          className="grid grid-cols-1 gap-6 md:grid-cols-3"
          variants={staggerContainer}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, amount: 0.15 }}
        >
          {styles.map((style) => (
            <motion.div
              key={style.name}
              variants={fadeUpVariants}
              className="group"
            >
              <StyleCard style={style} />
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
